class_name WorldMap
extends Node2D
## Spatial foundation of RestaurantWorld: map configuration, the grid, the
## object registry, stateless target-neighbor queries, and a temporary blockout.
##
## Spatial data only. It does not move the Player, route clicks, or own
## fixtures, orders, stock or money. Those belong to their documented owners.

const WORLD_ID_META: StringName = &"world_id"
const PARENT_WORLD_ID_META: StringName = &"parent_world_id"
const FOOTPRINT_SIZE_META: StringName = &"footprint_size"
const SLOT_ID_META: StringName = &"slot_id"
const ALLOWED_FIXTURE_KINDS_META: StringName = &"allowed_fixture_kinds"
const INVALID_CELL: Vector2i = Vector2i(-1, -1)

const COLOR_WAITING_LANE := Color(0.55, 0.45, 0.75)
const COLOR_KITCHEN := Color(0.80, 0.70, 0.50)
const COLOR_DINING := Color(0.55, 0.75, 0.55)
const COLOR_ONLINE := Color(0.45, 0.65, 0.85)
const COLOR_GRID_LINE := Color(0, 0, 0, 0.25)
const COLOR_OBJECT := Color(0.30, 0.22, 0.15)
const COLOR_ANCHOR := Color(1.0, 0.9, 0.2)
const COLOR_LABEL := Color(1, 1, 1)
const LABEL_FONT_SIZE: int = 8

## Provisional values from docs/WORLD_LAYOUT_AND_VIEWPORT.md (13x9 cells, 32px tiles).
@export var grid_size: Vector2i = Vector2i(13, 9)
@export var tile_size: Vector2i = Vector2i(32, 32)

## Zone blocks in cell coordinates. Kitchen and dining cells are walkable floor;
## the waiting lane and online area are not walkable for the Player.
@export var waiting_lane_rect: Rect2i = Rect2i(0, 0, 2, 9)
@export var kitchen_rect: Rect2i = Rect2i(2, 0, 9, 4)
@export var dining_rect: Rect2i = Rect2i(2, 4, 9, 5)
@export var online_rect: Rect2i = Rect2i(11, 0, 2, 9)

## Temporary visuals; turn off once real art replaces the blockout.
@export var show_blockout: bool = true

var grid: WorldGrid
var registry: WorldRegistry
var _cleanup_callables: Dictionary[StringName, Callable] = {}

@onready var floor_layer: TileMapLayer = $FloorTiles
@onready var dine_in_waiting_anchors: Node2D = $DineInWaitingAnchors
@onready var player: Node2D = $Player
@onready var kitchen_stations: Node2D = $KitchenStations
@onready var kitchen_work_tables: Node2D = $KitchenWorkTables
@onready var dining_tables: Node2D = $DiningTables
@onready var online_station: Area2D = $OnlineStation
@onready var driver_pickup_spots: Node2D = $DriverPickupSpots
@onready var driver_overflow_anchors: Node2D = $DriverOverflowAnchors
@onready var driver_objects: Node2D = $DriverObjects
@onready var placement_slots: Node2D = $PlacementSlots
@onready var decorations: Node2D = $Decorations


func _enter_tree() -> void:
	if grid != null:
		return

	grid = WorldGrid.new(grid_size, tile_size)
	if grid.is_valid():
		grid.set_walkable_rect(kitchen_rect, true)
		grid.set_walkable_rect(dining_rect, true)
	registry = WorldRegistry.new()


func _ready() -> void:
	_register_fixture_children(kitchen_stations)
	_register_work_tables(kitchen_work_tables)
	_register_fixture_children(dining_tables)
	_register_fixture_node(online_station)
	_register_anchor_children(dine_in_waiting_anchors)
	_register_anchor_children(driver_pickup_spots)
	_register_anchor_children(driver_overflow_anchors)
	_register_anchor_children(placement_slots)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_all_cleanups()


## Cell containing a global-space position, honoring this node's transform.
func global_to_cell(global_position_value: Vector2) -> Vector2i:
	return grid.local_to_cell(to_local(global_position_value))


## Global-space center of a cell, honoring this node's transform.
func cell_to_global(cell: Vector2i) -> Vector2:
	return to_global(grid.cell_to_local(cell))


## Registers a world object under a stable ID. A non-empty footprint also
## claims those cells in the grid. All-or-nothing: returns false and leaves
## no partial state on invalid input, a duplicate ID or overlapping cells.
func register_object(object_id: StringName, node: Node2D, footprint: Array[Vector2i] = []) -> bool:
	if not registry.register_object(object_id, node):
		return false

	if not footprint.is_empty() and not grid.occupy(object_id, footprint):
		registry.unregister_object(object_id)
		push_error("WorldMap: footprint for '%s' is invalid or overlaps." % object_id)
		return false

	_connect_cleanup(object_id, node)
	_request_redraw()
	return true


## Removes the object and frees its footprint. Returns false if unknown.
func unregister_object(object_id: StringName) -> bool:
	var node := registry.get_object(object_id)
	if not registry.unregister_object(object_id):
		return false

	_disconnect_cleanup(object_id, node)
	grid.release(object_id)
	_request_redraw()
	return true


## Occupied footprint cells for a physical fixture, or its parent fixture's
## footprint when `target_id` is a child interaction target. Returns an empty
## array for unknown IDs, passive markers, empty slots, or invalid references.
func get_target_footprint(target_id: StringName) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if target_id == &"" or grid == null or not grid.is_valid() or registry == null:
		return empty

	var node := registry.get_object(target_id)
	if node == null:
		return empty

	var direct := grid.get_footprint(target_id)
	if not direct.is_empty():
		return direct

	if node.has_meta(PARENT_WORLD_ID_META):
		var parent_id := StringName(node.get_meta(PARENT_WORLD_ID_META, &""))
		if parent_id == &"" or parent_id == target_id:
			return empty
		if registry.get_object(parent_id) == null:
			return empty
		return grid.get_footprint(parent_id)

	return empty


## Walkable, unoccupied cardinal neighbors of `target_id`'s footprint in fixed
## deterministic order (footprint cell order, then up, right, down, left).
func get_free_cardinal_neighbors(target_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var footprint := get_target_footprint(target_id)
	if footprint.is_empty():
		return result

	for neighbor in grid.get_footprint_neighbors(footprint):
		if grid.is_free(neighbor):
			result.append(neighbor)
	return result


## Nearest free cardinal neighbor of `target_id` from `from_cell` by Manhattan
## distance, breaking ties in deterministic cardinal order (up, right, down, left).
## Returns INVALID_CELL (-1, -1) if `target_id` or `from_cell` is invalid or no
## free neighbor exists.
func find_nearest_free_neighbor(target_id: StringName, from_cell: Vector2i) -> Vector2i:
	if grid == null or not grid.is_in_bounds(from_cell):
		return INVALID_CELL

	var neighbors := get_free_cardinal_neighbors(target_id)
	if neighbors.is_empty():
		return INVALID_CELL

	var best_cell := neighbors[0]
	var best_distance := _manhattan_distance(from_cell, best_cell)
	for i in range(1, neighbors.size()):
		var candidate := neighbors[i]
		var distance := _manhattan_distance(from_cell, candidate)
		if distance < best_distance:
			best_distance = distance
			best_cell = candidate
	return best_cell


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _register_fixture_children(container: Node2D) -> void:
	if container == null:
		return
	for child in container.get_children():
		var node := child as Node2D
		if node != null:
			_register_fixture_node(node)


func _register_fixture_node(node: Node2D) -> void:
	if node == null:
		return
	var object_id := StringName(node.get_meta(WORLD_ID_META, &""))
	var footprint := _build_node_footprint(node)
	if footprint.is_empty():
		return
	register_object(object_id, node, footprint)


func _register_work_tables(container: Node2D) -> void:
	if container == null:
		return
	for child in container.get_children():
		var table_node := child as Node2D
		if table_node == null:
			continue
		_register_fixture_node(table_node)
		for subchild in table_node.get_children():
			var target_node := subchild as Node2D
			if target_node == null or not target_node.has_meta(WORLD_ID_META):
				continue
			var target_id := StringName(target_node.get_meta(WORLD_ID_META, &""))
			register_object(target_id, target_node, [])


func _register_anchor_children(container: Node2D) -> void:
	if container == null:
		return
	for child in container.get_children():
		var node := child as Node2D
		if node == null:
			continue
		var object_id := StringName(node.get_meta(WORLD_ID_META, &""))
		register_object(object_id, node, [])


func _build_node_footprint(node: Node2D) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var raw_size: Variant = node.get_meta(FOOTPRINT_SIZE_META, Vector2i.ONE)
	if not (raw_size is Vector2i):
		push_error("WorldMap: invalid footprint_size metadata on '%s'." % node.name)
		return cells

	var footprint_size: Vector2i = raw_size
	if footprint_size.x <= 0 or footprint_size.y <= 0:
		push_error("WorldMap: non-positive footprint_size on '%s'." % node.name)
		return cells

	var origin_cell := global_to_cell(node.global_position)
	for dy in range(footprint_size.y):
		for dx in range(footprint_size.x):
			cells.append(origin_cell + Vector2i(dx, dy))
	return cells


func _connect_cleanup(object_id: StringName, node: Node2D) -> void:
	var cleanup_callable := _on_registered_node_tree_exiting.bind(
		object_id, node.get_instance_id()
	)
	_cleanup_callables[object_id] = cleanup_callable
	if not node.tree_exiting.is_connected(cleanup_callable):
		node.tree_exiting.connect(cleanup_callable)


func _disconnect_cleanup(object_id: StringName, node: Node2D) -> void:
	if not _cleanup_callables.has(object_id):
		return

	var cleanup_callable: Callable = _cleanup_callables[object_id]
	_cleanup_callables.erase(object_id)
	if is_instance_valid(node) and node.tree_exiting.is_connected(cleanup_callable):
		node.tree_exiting.disconnect(cleanup_callable)


func _disconnect_all_cleanups() -> void:
	if _cleanup_callables.is_empty():
		return

	var ids := _cleanup_callables.keys()
	for object_id: StringName in ids:
		var node := registry.get_object(object_id) if registry != null else null
		_disconnect_cleanup(object_id, node)


func _on_registered_node_tree_exiting(object_id: StringName, instance_id: int) -> void:
	if registry == null or grid == null:
		return

	var current := registry.get_object(object_id)
	if current == null or current.get_instance_id() != instance_id:
		return

	if not registry.unregister_node(object_id, current):
		return

	_disconnect_cleanup(object_id, current)
	grid.release(object_id)
	_request_redraw()


func _request_redraw() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		queue_redraw()


func _draw() -> void:
	if not show_blockout or grid == null or not grid.is_valid():
		return

	_draw_zone(waiting_lane_rect, COLOR_WAITING_LANE)
	_draw_zone(kitchen_rect, COLOR_KITCHEN)
	_draw_zone(dining_rect, COLOR_DINING)
	_draw_zone(online_rect, COLOR_ONLINE)
	_draw_grid_lines()

	for object_id in registry.get_ids():
		var node := registry.get_object(object_id)
		if node == null or node.has_meta(PARENT_WORLD_ID_META):
			continue

		var footprint := grid.get_footprint(object_id)
		if footprint.is_empty():
			var anchor_cell := global_to_cell(node.global_position)
			_draw_cell_box(anchor_cell, object_id, COLOR_ANCHOR, false)
			continue

		for cell in footprint:
			_draw_cell_box(cell, object_id, COLOR_OBJECT, true)


func _draw_zone(cell_rect: Rect2i, color: Color) -> void:
	draw_rect(grid.cell_rect_to_local(cell_rect), color)


func _draw_grid_lines() -> void:
	var extent := Vector2(grid.size * grid.tile_size)
	for x in range(grid.size.x + 1):
		var line_x := float(x * grid.tile_size.x)
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, extent.y), COLOR_GRID_LINE)
	for y in range(grid.size.y + 1):
		var line_y := float(y * grid.tile_size.y)
		draw_line(Vector2(0.0, line_y), Vector2(extent.x, line_y), COLOR_GRID_LINE)


func _draw_cell_box(cell: Vector2i, label: StringName, color: Color, filled: bool) -> void:
	var rect := grid.cell_rect_to_local(Rect2i(cell, Vector2i.ONE)).grow(-3.0)
	if filled:
		draw_rect(rect, color)
	else:
		draw_rect(rect, color, false, 2.0)

	var font := ThemeDB.fallback_font
	var text_position := rect.position + Vector2(0.0, rect.size.y * 0.5 + 3.0)
	draw_string(font, text_position, String(label).left(6), HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x, LABEL_FONT_SIZE, COLOR_LABEL)
