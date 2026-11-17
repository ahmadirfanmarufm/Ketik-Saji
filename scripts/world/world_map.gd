class_name WorldMap
extends Node2D
## Spatial foundation of RestaurantWorld: map configuration, the grid, the
## object registry, stateless target-neighbor queries, and world visual bindings.
##
## Spatial data and passive visual presentation only. It does not move the
## Player, route clicks, or own fixtures, orders, stock or money.

const WORLD_ID_META: StringName = &"world_id"
const PARENT_WORLD_ID_META: StringName = &"parent_world_id"
const FOOTPRINT_SIZE_META: StringName = &"footprint_size"
const SLOT_ID_META: StringName = &"slot_id"
const ALLOWED_FIXTURE_KINDS_META: StringName = &"allowed_fixture_kinds"
const INVALID_CELL: Vector2i = Vector2i(-1, -1)

const TILESET_SOURCE_ID: int = 0
const TILE_LANE_TOP_LEFT: Vector2i = Vector2i(0, 0)
const TILE_LANE_TOP_MID: Vector2i = Vector2i(1, 0)
const TILE_LANE_TOP_RIGHT: Vector2i = Vector2i(2, 0)
const TILE_LANE_MID_LEFT: Vector2i = Vector2i(0, 1)
const TILE_LANE_FILL: Vector2i = Vector2i(1, 1)
const TILE_LANE_MID_RIGHT: Vector2i = Vector2i(2, 1)
const TILE_LANE_BOT_LEFT: Vector2i = Vector2i(0, 2)
const TILE_LANE_BOT_MID: Vector2i = Vector2i(1, 2)
const TILE_LANE_BOT_RIGHT: Vector2i = Vector2i(2, 2)
const TILE_KITCHEN_FLOOR: Vector2i = Vector2i(8, 4)
const TILE_DINING_FLOOR: Vector2i = Vector2i(5, 4)

const REGION_FRIDGE: Rect2 = Rect2(352, 0, 32, 64)
const REGION_STORAGE_BOX: Rect2 = Rect2(352, 96, 32, 32)
const REGION_STOVE: Rect2 = Rect2(416, 96, 32, 32)
const REGION_STOVE_ACTIVE: Rect2 = Rect2(480, 96, 32, 32)
const REGION_WASHER: Rect2 = Rect2(544, 32, 32, 32)
const REGION_WASHER_FILLED: Rect2 = Rect2(608, 32, 32, 32)
const REGION_PLATE_RACK: Rect2 = Rect2(544, 128, 32, 64)
const REGION_RICE_COOKER: Rect2 = Rect2(672, 0, 32, 64)
const REGION_WORK_TABLE: Rect2 = Rect2(544, 96, 32, 32)
const REGION_TRASH: Rect2 = Rect2(608, 96, 32, 32)
const REGION_DINING_TABLE: Rect2 = Rect2(416, 160, 32, 32)
const REGION_ONLINE_STATION: Rect2 = Rect2(480, 128, 32, 64)

const DRIVER_HITBOX_SIZE: Vector2 = Vector2(28, 28)
const DRIVER_OVERFLOW_STEP: Vector2 = Vector2(0, -24)
const CUSTOMER_OVERFLOW_STEP: Vector2 = Vector2(0, -18)
const DINE_IN_WAITING_ANCHOR_IDS: Array[StringName] = [
	&"dine_in_wait_01",
	&"dine_in_wait_02",
	&"dine_in_wait_03",
	&"dine_in_wait_04",
]

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

## Temporary visuals; disabled by default once real tileset/sprite art is active.
@export var show_blockout: bool = false

@export var driver_texture: Texture2D = null
@export var employee_texture: Texture2D = null
@export var customer_textures: Array[Texture2D] = []

var grid: WorldGrid
var registry: WorldRegistry
var _cleanup_callables: Dictionary[StringName, Callable] = {}
var _driver_visual_nodes: Dictionary[StringName, Node2D] = {}
var _driver_visual_states: Dictionary[StringName, int] = {}
var _driver_visual_spots: Dictionary[StringName, StringName] = {}
var _customer_visual_nodes: Dictionary[StringName, Node2D] = {}

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
	_populate_floor_tiles()
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


## Deterministically selects a customer variant texture by zero-based index.
func get_customer_texture_by_index(index: int) -> Texture2D:
	if customer_textures.is_empty():
		return null
	return customer_textures[posmod(index, customer_textures.size())]


## Deterministically selects a customer variant texture for a stable `customer_id`.
func get_customer_texture_for_id(customer_id: StringName) -> Texture2D:
	if customer_textures.is_empty() or customer_id == &"":
		return null
	var hash_val := absi(String(customer_id).hash())
	return customer_textures[hash_val % customer_textures.size()]


## Returns the atlas region in `Warung-Tileset.png` for a `SharedTypes.FixtureKind`.
func get_fixture_region_rect(fixture_kind: int) -> Rect2:
	match fixture_kind:
		SharedTypes.FixtureKind.BOX:
			return REGION_STORAGE_BOX
		SharedTypes.FixtureKind.FRIDGE:
			return REGION_FRIDGE
		SharedTypes.FixtureKind.STOVE:
			return REGION_STOVE
		SharedTypes.FixtureKind.WASHER:
			return REGION_WASHER
		SharedTypes.FixtureKind.PLATE_RACK:
			return REGION_PLATE_RACK
		SharedTypes.FixtureKind.RICE_COOKER:
			return REGION_RICE_COOKER
		SharedTypes.FixtureKind.DINING_TABLE:
			return REGION_DINING_TABLE
	return Rect2()


## Synchronizes a food item container (held or staged) with plate and part sprites.
static func sync_food_item_visual(
	container: Node2D,
	has_item: bool,
	is_plated: bool,
	part_textures: Array[Texture2D]
) -> void:
	if container == null:
		return

	var old_children := container.get_children()
	for child in old_children:
		container.remove_child(child)
		child.free()

	container.visible = has_item
	if not has_item:
		return

	if is_plated:
		var plate := Polygon2D.new()
		plate.name = "PlateIndicator"
		plate.polygon = PackedVector2Array([
			Vector2(-9, -3),
			Vector2(9, -3),
			Vector2(10, 0),
			Vector2(8, 3),
			Vector2(-8, 3),
			Vector2(-10, 0),
		])
		plate.color = Color(0.95, 0.95, 0.95, 1.0)
		container.add_child(plate)

	var count := part_textures.size()
	if count == 0:
		return

	var spacing := 10.0
	var start_x := -0.5 * float(count - 1) * spacing
	var y_pos := -3.0 if is_plated else 0.0
	for i in range(count):
		var tex := part_textures[i]
		var pos := Vector2(start_x + float(i) * spacing, y_pos)
		if tex != null:
			var sprite := Sprite2D.new()
			sprite.name = "PartSprite_%d" % i
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.texture = tex
			sprite.position = pos
			container.add_child(sprite)
		else:
			var fallback := Polygon2D.new()
			fallback.name = "PartFallback_%d" % i
			fallback.polygon = PackedVector2Array([
				Vector2(-4, -4),
				Vector2(4, -4),
				Vector2(4, 4),
				Vector2(-4, 4),
			])
			fallback.color = Color(0.85, 0.72, 0.55, 1.0)
			fallback.position = pos
			container.add_child(fallback)


## Synchronizes passive kitchen station visuals (WorkTable staged item, PlateRack
## clean count, RiceCooker output, and Washer fill) from read-only views.
func sync_kitchen_visuals(
	work_table_has_item: bool,
	work_table_is_plated: bool,
	work_table_textures: Array[Texture2D],
	cooker_has_output: bool,
	cooker_texture: Texture2D,
	plate_clean_count: int,
	washer_dirty_count: int
) -> void:
	if registry == null:
		return

	var table_node := registry.get_object(&"work_table")
	if table_node != null:
		var staged_vis := table_node.get_node_or_null("StagedVisual") as Node2D
		if staged_vis == null:
			staged_vis = Node2D.new()
			staged_vis.name = "StagedVisual"
			staged_vis.z_index = 1
			staged_vis.position = Vector2(0, -4)
			staged_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			table_node.add_child(staged_vis)
		sync_food_item_visual(
			staged_vis,
			work_table_has_item,
			work_table_is_plated,
			work_table_textures
		)

	var rack_node := registry.get_object(&"plate_rack")
	if rack_node != null:
		var rack_sprite := rack_node.get_node_or_null("Sprite2D") as Sprite2D
		if rack_sprite != null:
			rack_sprite.modulate = (
				Color.WHITE if plate_clean_count > 0 else Color(0.65, 0.65, 0.65, 1.0)
			)
		var count_label := rack_node.get_node_or_null("PlateCountLabel") as Label
		if count_label == null:
			count_label = Label.new()
			count_label.name = "PlateCountLabel"
			count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count_label.z_index = 2
			count_label.position = Vector2(6, -18)
			count_label.add_theme_font_size_override("font_size", 8)
			rack_node.add_child(count_label)
		count_label.text = str(plate_clean_count)

	var cooker_node := registry.get_object(&"rice_cooker")
	if cooker_node != null:
		var cooker_vis := cooker_node.get_node_or_null("CookerOutputVisual") as Node2D
		if cooker_vis == null:
			cooker_vis = Node2D.new()
			cooker_vis.name = "CookerOutputVisual"
			cooker_vis.z_index = 2
			cooker_vis.position = Vector2(0, -20)
			cooker_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cooker_node.add_child(cooker_vis)
		var cooker_textures: Array[Texture2D] = []
		if cooker_has_output:
			cooker_textures.append(cooker_texture)
		sync_food_item_visual(cooker_vis, cooker_has_output, false, cooker_textures)

	var washer_node := registry.get_object(&"washer")
	if washer_node != null:
		var washer_sprite := washer_node.get_node_or_null("Sprite2D") as Sprite2D
		if washer_sprite != null:
			washer_sprite.region_rect = (
				REGION_WASHER_FILLED if washer_dirty_count > 0 else REGION_WASHER
			)


## Synchronizes runtime delivery driver visuals under `DriverObjects` from
## `ServiceController.get_driver_views()` without duplicating controller state.
func sync_driver_visuals(driver_views: Array[Dictionary]) -> void:
	if driver_objects == null or registry == null or grid == null:
		return

	var seen_ids: Dictionary[StringName, bool] = {}
	for view: Dictionary in driver_views:
		var driver_id := StringName(view.get("driver_id", &""))
		if driver_id != &"":
			seen_ids[driver_id] = true

	var existing_ids := _driver_visual_nodes.keys()
	for old_id: StringName in existing_ids:
		if not seen_ids.has(old_id):
			_remove_driver_visual(old_id)

	var overflow_index := 0
	for view: Dictionary in driver_views:
		var driver_id := StringName(view.get("driver_id", &""))
		if driver_id == &"":
			continue
		var state := int(view.get("state", SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE))
		var spot_id := StringName(view.get("spot_id_or_empty", view.get("spot_id", &"")))
		if state == SharedTypes.DriverState.AT_PICKUP_SPOT and spot_id != &"":
			_sync_in_spot_driver_visual(driver_id, spot_id)
		else:
			_sync_overflow_driver_visual(driver_id, overflow_index)
			overflow_index += 1


func _sync_in_spot_driver_visual(driver_id: StringName, spot_id: StringName) -> void:
	var spot_node := registry.get_object(spot_id)
	if spot_node == null:
		_remove_driver_visual(driver_id)
		return

	if _driver_visual_nodes.has(driver_id):
		var prev_state := int(_driver_visual_states.get(driver_id, -1))
		var prev_spot := StringName(_driver_visual_spots.get(driver_id, &""))
		if prev_state != SharedTypes.DriverState.AT_PICKUP_SPOT or prev_spot != spot_id:
			_remove_driver_visual(driver_id)

	if not _driver_visual_nodes.has(driver_id):
		var area := Area2D.new()
		area.name = String(driver_id)
		area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		area.z_index = 1
		area.position = spot_node.position
		area.set_meta(WORLD_ID_META, driver_id)

		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = DRIVER_HITBOX_SIZE
		shape_node.shape = rect_shape
		area.add_child(shape_node)

		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = driver_texture
		area.add_child(sprite)

		driver_objects.add_child(area)
		var spot_cell := global_to_cell(spot_node.global_position)
		if not register_object(driver_id, area, [spot_cell]):
			driver_objects.remove_child(area)
			area.free()
			return

		_driver_visual_nodes[driver_id] = area
		_driver_visual_states[driver_id] = SharedTypes.DriverState.AT_PICKUP_SPOT
		_driver_visual_spots[driver_id] = spot_id
	else:
		var node := _driver_visual_nodes[driver_id]
		if is_instance_valid(node):
			node.position = spot_node.position


func _sync_overflow_driver_visual(driver_id: StringName, queue_index: int) -> void:
	var overflow_anchor := registry.get_object(&"driver_overflow")
	var base_pos := overflow_anchor.position if overflow_anchor != null else Vector2(400, 240)
	var target_pos := base_pos + DRIVER_OVERFLOW_STEP * float(queue_index)

	if _driver_visual_nodes.has(driver_id):
		var prev_state := int(_driver_visual_states.get(driver_id, -1))
		if prev_state != SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE:
			_remove_driver_visual(driver_id)

	if not _driver_visual_nodes.has(driver_id):
		var marker := Node2D.new()
		marker.name = String(driver_id)
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		marker.z_index = 1
		marker.position = target_pos

		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = driver_texture
		marker.add_child(sprite)

		driver_objects.add_child(marker)
		_driver_visual_nodes[driver_id] = marker
		_driver_visual_states[driver_id] = SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE
		_driver_visual_spots[driver_id] = &""
	else:
		var node := _driver_visual_nodes[driver_id]
		if is_instance_valid(node):
			node.position = target_pos


func _remove_driver_visual(driver_id: StringName) -> void:
	if registry != null and registry.has_object(driver_id):
		unregister_object(driver_id)
	var node: Node2D = _driver_visual_nodes.get(driver_id, null)
	_driver_visual_nodes.erase(driver_id)
	_driver_visual_states.erase(driver_id)
	_driver_visual_spots.erase(driver_id)
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


## Synchronizes passive dine-in customer sprites, order/timer badges, and table
## state visuals from read-only controller views without owning gameplay state.
func sync_dine_in_visuals(
	customer_views: Array[Dictionary],
	table_views: Array[Dictionary],
	recipe_names: Dictionary = {}
) -> void:
	if registry == null:
		return

	if dine_in_waiting_anchors != null:
		_sync_customer_visuals(customer_views, recipe_names)
	_sync_dining_table_visuals(table_views)


func get_customer_visual_node(customer_id: StringName) -> Node2D:
	return _customer_visual_nodes.get(customer_id, null)


func _sync_customer_visuals(
	customer_views: Array[Dictionary],
	recipe_names: Dictionary
) -> void:
	var seen_ids: Dictionary[StringName, bool] = {}
	for view: Dictionary in customer_views:
		var customer_id := StringName(view.get("customer_id", &""))
		var state: int = int(view.get("state", -1))
		if customer_id == &"" or state == SharedTypes.CustomerState.LEFT:
			continue
		seen_ids[customer_id] = true
		var marker := _ensure_customer_visual_node(customer_id)
		if marker == null:
			continue
		marker.position = _resolve_customer_visual_position(view)
		_update_customer_visual_badge(marker, view, recipe_names)

	var existing_ids := _customer_visual_nodes.keys()
	for old_id: StringName in existing_ids:
		if not seen_ids.has(old_id):
			_remove_customer_visual(old_id)


func _ensure_customer_visual_node(customer_id: StringName) -> Node2D:
	var existing: Node2D = _customer_visual_nodes.get(customer_id, null)
	if existing != null and is_instance_valid(existing):
		return existing

	var marker := Node2D.new()
	marker.name = String(customer_id)
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.z_index = 2

	var tex := get_customer_texture_for_id(customer_id)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = tex
		marker.add_child(sprite)
	else:
		var fallback := Polygon2D.new()
		fallback.name = "FallbackBody"
		fallback.polygon = PackedVector2Array([
			Vector2(-6, -10),
			Vector2(6, -10),
			Vector2(6, 8),
			Vector2(-6, 8),
		])
		fallback.color = Color(0.85, 0.55, 0.35, 1.0)
		marker.add_child(fallback)

	var bar_bg := ColorRect.new()
	bar_bg.name = "TimerBg"
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.color = Color(0.1, 0.1, 0.12, 0.85)
	bar_bg.position = Vector2(-14, -22)
	bar_bg.size = Vector2(28, 3)
	marker.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "TimerFill"
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.color = Color(0.35, 0.88, 0.42, 1.0)
	bar_fill.position = Vector2(0, 0)
	bar_fill.size = Vector2(28, 3)
	bar_bg.add_child(bar_fill)

	var label := Label.new()
	label.name = "StatusLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-24, -34)
	label.custom_minimum_size = Vector2(48, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 7)
	marker.add_child(label)

	dine_in_waiting_anchors.add_child(marker)
	_customer_visual_nodes[customer_id] = marker
	return marker


func _resolve_customer_visual_position(view: Dictionary) -> Vector2:
	var state: int = int(view.get("state", -1))
	if state == SharedTypes.CustomerState.OUTSIDE_WAITING:
		var queue_idx: int = maxi(0, int(view.get("queue_index", 0)))
		var anchor_idx := mini(queue_idx, DINE_IN_WAITING_ANCHOR_IDS.size() - 1)
		var overflow := maxi(0, queue_idx - (DINE_IN_WAITING_ANCHOR_IDS.size() - 1))
		var anchor_node := registry.get_object(DINE_IN_WAITING_ANCHOR_IDS[anchor_idx])
		if anchor_node != null:
			var local_base := dine_in_waiting_anchors.to_local(anchor_node.global_position)
			return local_base + CUSTOMER_OVERFLOW_STEP * float(overflow)
		return Vector2(48, 80) + CUSTOMER_OVERFLOW_STEP * float(queue_idx)

	var table_id := StringName(view.get("assigned_table_id", &""))
	var table_node := registry.get_object(table_id)
	if table_node != null:
		return dine_in_waiting_anchors.to_local(table_node.global_position) + Vector2(0, -12)
	return Vector2(144, 196)


func _update_customer_visual_badge(
	marker: Node2D,
	view: Dictionary,
	recipe_names: Dictionary
) -> void:
	var state: int = int(view.get("state", -1))
	var label := marker.get_node_or_null("StatusLabel") as Label
	var bar_fill := marker.get_node_or_null("TimerBg/TimerFill") as ColorRect
	var ratio := 1.0

	if state == SharedTypes.CustomerState.EATING:
		var eat_rem: float = float(view.get("eat_seconds_remaining", 0.0))
		var eat_total: float = maxf(0.1, float(view.get("eat_total_seconds", 20.0)))
		ratio = clampf(eat_rem / eat_total, 0.0, 1.0)
		if label != null:
			label.text = "Makan %ds" % ceili(eat_rem)
		if bar_fill != null:
			bar_fill.color = Color(0.4, 0.78, 0.96, 1.0)
	else:
		var recipe_id := StringName(view.get("recipe_id", &""))
		var dish_text: String = String(recipe_names.get(recipe_id, String(recipe_id)))
		var wait_rem: float = float(view.get("wait_seconds_remaining", 0.0))
		var wait_total: float = maxf(0.1, float(view.get("wait_total_seconds", 100.0)))
		ratio = clampf(wait_rem / wait_total, 0.0, 1.0)
		if label != null:
			label.text = "%s %ds" % [dish_text, ceili(wait_rem)]
		if bar_fill != null:
			if ratio <= 0.25:
				bar_fill.color = Color(0.95, 0.28, 0.25, 1.0)
			elif ratio <= 0.55:
				bar_fill.color = Color(0.95, 0.76, 0.25, 1.0)
			else:
				bar_fill.color = Color(0.35, 0.88, 0.42, 1.0)

	if bar_fill != null:
		bar_fill.size = Vector2(28.0 * ratio, 3.0)


func _remove_customer_visual(customer_id: StringName) -> void:
	var node: Node2D = _customer_visual_nodes.get(customer_id, null)
	_customer_visual_nodes.erase(customer_id)
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _sync_dining_table_visuals(table_views: Array[Dictionary]) -> void:
	for view: Dictionary in table_views:
		var table_id := StringName(view.get("table_id", &""))
		var state: int = int(view.get("state", -1))
		var table_node := registry.get_object(table_id)
		if table_node == null:
			continue

		var dirty_vis := table_node.get_node_or_null("TableDirtyVisual") as Node2D
		if dirty_vis == null and state == SharedTypes.TableState.DIRTY:
			dirty_vis = _create_table_dirty_visual()
			table_node.add_child(dirty_vis)
		if dirty_vis != null:
			dirty_vis.visible = (state == SharedTypes.TableState.DIRTY)

		var plate_vis := table_node.get_node_or_null("TablePlateVisual") as Node2D
		if plate_vis == null and state == SharedTypes.TableState.OCCUPIED_EATING:
			plate_vis = _create_table_plate_visual()
			table_node.add_child(plate_vis)
		if plate_vis != null:
			plate_vis.visible = (state == SharedTypes.TableState.OCCUPIED_EATING)


func _create_table_dirty_visual() -> Node2D:
	var container := Node2D.new()
	container.name = "TableDirtyVisual"
	container.z_index = 1
	container.position = Vector2(0, -4)

	var messy_plate := Polygon2D.new()
	messy_plate.name = "DirtyPlate"
	messy_plate.polygon = PackedVector2Array([
		Vector2(-7, -3),
		Vector2(7, -3),
		Vector2(8, 2),
		Vector2(-8, 2),
	])
	messy_plate.color = Color(0.62, 0.48, 0.34, 1.0)
	container.add_child(messy_plate)

	var badge := Label.new()
	badge.name = "DirtyLabel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(-16, -15)
	badge.custom_minimum_size = Vector2(32, 10)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.text = "Kotor"
	badge.add_theme_font_size_override("font_size", 7)
	badge.modulate = Color(1.0, 0.55, 0.38, 1.0)
	container.add_child(badge)
	return container


func _create_table_plate_visual() -> Node2D:
	var container := Node2D.new()
	container.name = "TablePlateVisual"
	container.z_index = 1
	container.position = Vector2(0, -4)

	var clean_plate := Polygon2D.new()
	clean_plate.name = "ServedPlate"
	clean_plate.polygon = PackedVector2Array([
		Vector2(-7, -3),
		Vector2(7, -3),
		Vector2(8, 2),
		Vector2(-8, 2),
	])
	clean_plate.color = Color(0.95, 0.95, 0.92, 1.0)
	container.add_child(clean_plate)

	var food_dot := Polygon2D.new()
	food_dot.name = "ServedDishDot"
	food_dot.polygon = PackedVector2Array([
		Vector2(-4, -2),
		Vector2(4, -2),
		Vector2(4, 1),
		Vector2(-4, 1),
	])
	food_dot.color = Color(0.96, 0.78, 0.32, 1.0)
	container.add_child(food_dot)
	return container


func _populate_floor_tiles() -> void:
	if floor_layer == null or floor_layer.tile_set == null:
		return
	if not floor_layer.get_used_cells().is_empty():
		return

	_fill_bordered_lane(waiting_lane_rect)
	_fill_flat_zone(kitchen_rect, TILE_KITCHEN_FLOOR)
	_fill_flat_zone(dining_rect, TILE_DINING_FLOOR)
	_fill_bordered_lane(online_rect)


func _fill_flat_zone(rect: Rect2i, atlas_coords: Vector2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			floor_layer.set_cell(Vector2i(x, y), TILESET_SOURCE_ID, atlas_coords)


func _fill_bordered_lane(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var is_left := (x == rect.position.x)
			var is_right := (x == rect.end.x - 1)
			var is_top := (y == rect.position.y)
			var is_bot := (y == rect.end.y - 1)
			var coords := TILE_LANE_FILL
			if is_top and is_left:
				coords = TILE_LANE_TOP_LEFT
			elif is_top and is_right:
				coords = TILE_LANE_TOP_RIGHT
			elif is_top:
				coords = TILE_LANE_TOP_MID
			elif is_bot and is_left:
				coords = TILE_LANE_BOT_LEFT
			elif is_bot and is_right:
				coords = TILE_LANE_BOT_RIGHT
			elif is_bot:
				coords = TILE_LANE_BOT_MID
			elif is_left:
				coords = TILE_LANE_MID_LEFT
			elif is_right:
				coords = TILE_LANE_MID_RIGHT
			floor_layer.set_cell(Vector2i(x, y), TILESET_SOURCE_ID, coords)


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
