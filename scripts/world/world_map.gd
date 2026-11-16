class_name WorldMap
extends Node2D
## Spatial foundation of RestaurantWorld: map configuration, the grid, the
## object registry, and a temporary visual blockout.
##
## Spatial data only. It does not move the Player, route clicks, or own
## fixtures, orders, stock or money. Those belong to their documented owners.
##
## Scene-authored objects (children of KitchenStations, DiningTables, OnlineArea) declare a
## stable ID with node metadata `world_id` and are registered on _ready. Kitchen
## stations and dining tables claim the single cell under their position (provisional
## single-cell footprints); OnlineArea markers are registered as anchors only and
## claim no cells.

const WORLD_ID_META: StringName = &"world_id"

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
@onready var decorations: Node2D = $Decorations
@onready var fixtures: Node2D = $KitchenStations
@onready var dining_area: Node2D = $DiningTables
@onready var waiting_lane: Node2D = $WaitingLane
@onready var online_area: Node2D = $OnlineArea
@onready var placement_slots: Node2D = $PlacementSlots


func _enter_tree() -> void:
	if grid != null:
		return

	grid = WorldGrid.new(grid_size, tile_size)
	if grid.is_valid():
		grid.set_walkable_rect(kitchen_rect, true)
		grid.set_walkable_rect(dining_rect, true)
	registry = WorldRegistry.new()


func _ready() -> void:
	_register_children(fixtures, true)
	_register_children(dining_area, true)
	_register_children(online_area, false)
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


func _register_children(container: Node2D, claim_cell: bool) -> void:
	for child in container.get_children():
		var node := child as Node2D
		if node == null:
			continue

		var object_id := StringName(node.get_meta(WORLD_ID_META, &""))
		var footprint: Array[Vector2i] = []
		if claim_cell:
			footprint.append(global_to_cell(node.global_position))
		register_object(object_id, node, footprint)


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
		if node == null:
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
