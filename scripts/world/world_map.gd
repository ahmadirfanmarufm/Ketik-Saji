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
const SIDEWALK_SOURCE_ID: int = 1
const ROAD_SOURCE_ID: int = 2
const TILE_SIDEWALK: Vector2i = Vector2i(0, 0)
const SIDEWALK_ALT_DEFAULT: int = 0
const SIDEWALK_ALT_FLIPPED: int = 1
const TILE_ROAD_TOP: Vector2i = Vector2i(0, 0)
const TILE_ROAD_BOTTOM: Vector2i = Vector2i(0, 1)
const TILE_LANE_TOP_LEFT: Vector2i = Vector2i(0, 0)
const TILE_LANE_TOP_MID: Vector2i = Vector2i(1, 0)
const TILE_LANE_TOP_RIGHT: Vector2i = Vector2i(2, 0)
const TILE_LANE_MID_LEFT: Vector2i = Vector2i(0, 1)
const TILE_LANE_FILL: Vector2i = Vector2i(1, 1)
const TILE_LANE_MID_RIGHT: Vector2i = Vector2i(2, 1)
const TILE_LANE_BOT_LEFT: Vector2i = Vector2i(0, 2)
const TILE_LANE_BOT_MID: Vector2i = Vector2i(1, 2)
const TILE_LANE_BOT_RIGHT: Vector2i = Vector2i(2, 2)
const TILE_SINGLE_LANE_TOP: Vector2i = Vector2i(3, 0)
const TILE_SINGLE_LANE_MID: Vector2i = Vector2i(3, 1)
const TILE_SINGLE_LANE_BOT: Vector2i = Vector2i(3, 2)
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
const REGION_DINING_CHAIR: Rect2 = Rect2(416, 160, 32, 32)
const REGION_ONLINE_STATION: Rect2 = Rect2(480, 128, 32, 64)
const REGION_LONG_COUNTER: Rect2 = Rect2(416, 32, 96, 32)
const REGION_INTERIOR_WALL: Rect2 = Rect2(160, 64, 32, 32)
const DINING_TABLE_SCENE: PackedScene = preload("res://scenes/world/dining_table.tscn")
const PLATE_TEXTURE: Texture2D = preload("res://assets/art/dishes/plate.png")
const DIRTY_PLATE_TEXTURE: Texture2D = preload("res://assets/art/ui/icons/plate-dirty.png")

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

## Approved M5-A1 values from docs/WORLD_LAYOUT_AND_VIEWPORT.md (12x9 cells, 32px tiles).
@export var grid_size: Vector2i = Vector2i(12, 9)
@export var tile_size: Vector2i = Vector2i(32, 32)

## Zone blocks in cell coordinates. Kitchen, dining, and doorway cells are walkable floor;
## the long counter, pickup spots, interior wall, waiting lane, and road are not walkable.
@export var waiting_lane_rect: Rect2i = Rect2i(9, 0, 1, 9)
@export var kitchen_rect: Rect2i = Rect2i(0, 0, 8, 4)
@export var dining_rect: Rect2i = Rect2i(0, 4, 8, 5)
@export var online_rect: Rect2i = Rect2i(10, 0, 2, 9)
@export var long_counter_rect: Rect2i = Rect2i(0, 4, 6, 1)
@export var pickup_lane_rect: Rect2i = Rect2i(7, 5, 1, 3)
@export var wall_top_rect: Rect2i = Rect2i(8, 0, 1, 5)
@export var doorway_rect: Rect2i = Rect2i(8, 5, 1, 3)
@export var wall_bottom_rect: Rect2i = Rect2i(8, 8, 1, 1)

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
var _driver_target_positions: Dictionary[StringName, Vector2] = {}
var _driver_tweens: Dictionary[StringName, Tween] = {}
var _customer_visual_nodes: Dictionary[StringName, Node2D] = {}
var _customer_target_positions: Dictionary[StringName, Vector2] = {}
var _customer_tweens: Dictionary[StringName, Tween] = {}
var _departing_visuals: Array[Node2D] = []
var _departing_tweens: Array[Tween] = []
var _employee_visual_nodes: Dictionary[StringName, Node2D] = {}
var _employee_visual_states: Dictionary[StringName, Dictionary] = {}
var _employee_visual_container: Node2D = null
var _employee_anim_clock: float = 0.0
var _last_online_preview_key: String = ""

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
		grid.set_walkable_rect(doorway_rect, true)
		grid.set_walkable_rect(long_counter_rect, false)
		grid.set_walkable_rect(pickup_lane_rect, false)
		grid.set_walkable_rect(wall_top_rect, false)
		grid.set_walkable_rect(wall_bottom_rect, false)
		grid.set_walkable_rect(waiting_lane_rect, false)
		grid.set_walkable_rect(online_rect, false)
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


func _exit_tree() -> void:
	_clear_all_visual_tweens()


func _process(delta: float) -> void:
	if delta <= 0.0 or _employee_visual_nodes.is_empty():
		return
	if is_inside_tree() and get_tree() != null and get_tree().paused:
		return
	_employee_anim_clock += delta
	_step_employee_visual_animations(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_all_visual_tweens()
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
	return Rect2()


## Synchronizes a food item container (held or staged) with completed dish icon,
## ordinary plate sprite, and ingredient part sprites.
static func sync_food_item_visual(
	container: Node2D,
	has_item: bool,
	is_plated: bool,
	part_textures: Array[Texture2D],
	dish_icon: Texture2D = null
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

	if dish_icon != null:
		var dish_spr := Sprite2D.new()
		dish_spr.name = "DishSprite"
		dish_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dish_spr.texture = dish_icon
		dish_spr.scale = Vector2(0.75, 0.75)
		container.add_child(dish_spr)
		return

	if is_plated:
		var plate := Sprite2D.new()
		plate.name = "PlateIndicator"
		plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		plate.texture = PLATE_TEXTURE
		plate.scale = Vector2(0.75, 0.75)
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


## Returns stable IDs for all independent three-tile long counter slots.
func get_long_counter_slot_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if kitchen_work_tables == null:
		return ids
	for child in kitchen_work_tables.get_children():
		if not child.has_meta(WORLD_ID_META):
			continue
		var wid := StringName(child.get_meta(WORLD_ID_META, &""))
		if wid != &"" and wid != &"work_table":
			ids.append(wid)
	return ids


## Synchronizes passive visuals on the six independent three-tile long counter slots.
func sync_counter_slot_visuals(slot_views: Dictionary) -> void:
	if registry == null:
		return
	for slot_id in get_long_counter_slot_ids():
		var slot_node := registry.get_object(slot_id)
		if slot_node == null:
			continue
		var info: Dictionary = slot_views.get(slot_id, {})
		var has_item := not info.is_empty()
		var is_plated := bool(info.get("is_plated", false))
		var part_textures: Array[Texture2D] = []
		var raw_textures: Variant = info.get("textures", [])
		if raw_textures is Array:
			for tex_v: Variant in (raw_textures as Array):
				if tex_v is Texture2D:
					part_textures.append(tex_v as Texture2D)
		var dish_icon := info.get("dish_icon", null) as Texture2D
		var staged_vis := slot_node.get_node_or_null("StagedVisual") as Node2D
		if staged_vis == null:
			if not has_item:
				continue
			staged_vis = Node2D.new()
			staged_vis.name = "StagedVisual"
			staged_vis.z_index = 1
			staged_vis.position = Vector2(0, -4)
			staged_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			slot_node.add_child(staged_vis)
		sync_food_item_visual(staged_vis, has_item, is_plated, part_textures, dish_icon)


## Synchronizes passive kitchen station visuals (WorkTable staged item, PlateRack
## clean count, RiceCooker output, and Washer fill) from read-only views.
func sync_kitchen_visuals(
	work_table_has_item: bool,
	work_table_is_plated: bool,
	work_table_textures: Array[Texture2D],
	cooker_has_output: bool,
	cooker_texture: Texture2D,
	plate_clean_count: int,
	washer_dirty_count: int,
	cooker_portions: int = -1,
	work_table_dish_icon: Texture2D = null
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
			staged_vis.position = Vector2(-5, -4)
			staged_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			table_node.add_child(staged_vis)
		sync_food_item_visual(
			staged_vis,
			work_table_has_item,
			work_table_is_plated,
			work_table_textures,
			work_table_dish_icon
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
		var resolved_portions := (
			cooker_portions if cooker_portions >= 0 else (1 if cooker_has_output else 0)
		)
		_sync_cooker_node_visual(cooker_node, cooker_has_output, resolved_portions, cooker_texture)

	var washer_node := registry.get_object(&"washer")
	if washer_node != null:
		var washer_sprite := washer_node.get_node_or_null("Sprite2D") as Sprite2D
		if washer_sprite != null:
			washer_sprite.region_rect = (
				REGION_WASHER_FILLED if washer_dirty_count > 0 else REGION_WASHER
			)


## Updates live pending-delivery countdown badges on destination storage stations.
func sync_storage_delivery_visuals(pending_by_unit: Dictionary) -> void:
	if registry == null:
		return
	for unit_id in registry.get_ids():
		var unit_node := registry.get_object(unit_id)
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		var has_pending := pending_by_unit.has(unit_id)
		var badge := unit_node.get_node_or_null("DeliveryPendingLabel") as Label
		if badge == null and not has_pending:
			continue
		if badge == null:
			badge = Label.new()
			badge.name = "DeliveryPendingLabel"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.z_index = 2
			badge.position = Vector2(-20, -20)
			badge.custom_minimum_size = Vector2(40, 12)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_theme_font_size_override("font_size", 7)
			badge.modulate = Color(1.0, 0.88, 0.35, 1.0)
			unit_node.add_child(badge)
		badge.visible = has_pending
		if has_pending:
			var secs := maxi(0, ceili(float(pending_by_unit[unit_id])))
			badge.text = "Kirim %ds" % secs


## Synchronizes visuals for dynamically placed plate racks and rice cookers.
func sync_extra_kitchen_visuals(cooker_views: Dictionary, rack_views: Dictionary) -> void:
	if registry == null:
		return
	for rack_id: StringName in rack_views:
		if rack_id == &"plate_rack":
			continue
		var rack_node := registry.get_object(rack_id)
		if rack_node == null:
			continue
		var raw_rack: Variant = rack_views[rack_id]
		var clean_count := 0
		if raw_rack is Dictionary:
			clean_count = int((raw_rack as Dictionary).get("clean_count", 0))
		else:
			clean_count = int(raw_rack)
		var rack_sprite := rack_node.get_node_or_null("Sprite2D") as Sprite2D
		if rack_sprite != null:
			rack_sprite.modulate = (
				Color.WHITE if clean_count > 0 else Color(0.65, 0.65, 0.65, 1.0)
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
		count_label.text = str(clean_count)

	for cooker_id: StringName in cooker_views:
		if cooker_id == &"rice_cooker":
			continue
		var cooker_node := registry.get_object(cooker_id)
		if cooker_node == null:
			continue
		var info: Dictionary = cooker_views[cooker_id]
		var has_out := bool(info.get("has_output", false))
		var portions := int(info.get("portions", 1 if has_out else 0))
		var tex := info.get("texture", null) as Texture2D
		_sync_cooker_node_visual(cooker_node, has_out, portions, tex)


func _sync_cooker_node_visual(
	cooker_node: Node2D,
	has_output: bool,
	portion_count: int,
	cooker_texture: Texture2D
) -> void:
	if cooker_node == null:
		return
	var show_output := has_output and portion_count > 0
	var cooker_vis := cooker_node.get_node_or_null("CookerOutputVisual") as Node2D
	if cooker_vis == null:
		cooker_vis = Node2D.new()
		cooker_vis.name = "CookerOutputVisual"
		cooker_vis.z_index = 2
		cooker_vis.position = Vector2(0, -20)
		cooker_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cooker_node.add_child(cooker_vis)
	var textures: Array[Texture2D] = []
	if show_output:
		textures.append(cooker_texture)
	sync_food_item_visual(cooker_vis, show_output, false, textures)

	var portion_label := cooker_node.get_node_or_null("CookerPortionLabel") as Label
	if portion_label == null:
		portion_label = Label.new()
		portion_label.name = "CookerPortionLabel"
		portion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portion_label.z_index = 3
		portion_label.position = Vector2(6, -20)
		portion_label.add_theme_font_size_override("font_size", 8)
		cooker_node.add_child(portion_label)
	portion_label.visible = show_output
	portion_label.text = str(portion_count) if show_output else ""


## Synchronizes passive OnlineStation preview dish and availability tint from
## ServiceController's read-only offer view.
func sync_online_station_visual(
	preview_recipe_id: StringName,
	acceptance_enabled: bool,
	recipe_label: String = "",
	part_textures: Array[Texture2D] = [],
	dish_icon: Texture2D = null
) -> void:
	if registry == null:
		return

	var station_node := registry.get_object(&"online_station")
	if station_node == null:
		return

	var station_sprite := station_node.get_node_or_null("Sprite2D") as Sprite2D
	var preview_vis := station_node.get_node_or_null("OnlinePreviewVisual") as Node2D
	if preview_recipe_id == &"":
		_last_online_preview_key = ""
		if preview_vis != null:
			preview_vis.visible = false
		if station_sprite != null:
			station_sprite.modulate = Color.WHITE
		return

	if preview_vis == null:
		preview_vis = _create_online_preview_visual()
		station_node.add_child(preview_vis)

	preview_vis.visible = true
	var display_name := recipe_label if not recipe_label.is_empty() else String(preview_recipe_id)
	var icon_tag := 1 if dish_icon != null else 0
	var cache_key := "%s|%s|%d|%d" % [
		String(preview_recipe_id), display_name, part_textures.size(), icon_tag
	]
	if _last_online_preview_key != cache_key:
		_last_online_preview_key = cache_key
		var dish_node := preview_vis.get_node_or_null("PreviewDish") as Node2D
		sync_food_item_visual(dish_node, true, true, part_textures, dish_icon)
		var label_node := preview_vis.get_node_or_null("PreviewLabel") as Label
		if label_node != null:
			label_node.text = display_name

	preview_vis.modulate = Color.WHITE if acceptance_enabled else Color(0.55, 0.55, 0.55, 0.65)
	if station_sprite != null:
		station_sprite.modulate = (
			Color.WHITE if acceptance_enabled else Color(0.75, 0.75, 0.75, 1.0)
		)


func get_online_preview_visual() -> Node2D:
	if registry == null:
		return null
	var station_node := registry.get_object(&"online_station")
	if station_node == null:
		return null
	return station_node.get_node_or_null("OnlinePreviewVisual") as Node2D


## Shared exact CollisionShape2D hit-test against an Area2D in world coordinates.
static func point_hits_area_shapes(area: Area2D, world_global_pos: Vector2) -> bool:
	if area == null or not is_instance_valid(area):
		return false
	for child in area.get_children():
		if not (child is CollisionShape2D):
			continue
		var shape_node := child as CollisionShape2D
		if not is_instance_valid(shape_node) or shape_node.disabled or shape_node.shape == null:
			continue
		var xform := shape_node.get_global_transform()
		if is_zero_approx(xform.determinant()):
			continue
		var local_pt := xform.affine_inverse() * world_global_pos
		if shape_node.shape is RectangleShape2D:
			var rect_shape := shape_node.shape as RectangleShape2D
			if rect_shape.get_rect().has_point(local_pt):
				return true
		elif shape_node.shape is CircleShape2D:
			var circle_shape := shape_node.shape as CircleShape2D
			if local_pt.length_squared() <= circle_shape.radius * circle_shape.radius:
				return true
	return false


func hit_test_overflow_driver(world_global_pos: Vector2) -> StringName:
	if driver_objects == null:
		return &""
	var children := driver_objects.get_children()
	for i in range(children.size() - 1, -1, -1):
		var area := children[i] as Area2D
		if area == null or not is_instance_valid(area) or not area.is_visible_in_tree():
			continue
		var driver_id := StringName(area.get_meta(WORLD_ID_META, &""))
		if driver_id == &"":
			continue
		var drv_state := int(_driver_visual_states.get(driver_id, -1))
		if drv_state != SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE:
			continue
		if point_hits_area_shapes(area, world_global_pos):
			return driver_id
	return &""


## Hit-tests unoccupied PlacementSlot markers in world global coordinates.
func hit_test_placement_slot(world_global_pos: Vector2) -> StringName:
	if placement_slots == null or grid == null:
		return &""
	for child in placement_slots.get_children():
		var slot_node := child as Node2D
		if slot_node == null or not is_instance_valid(slot_node):
			continue
		var slot_id := StringName(slot_node.get_meta(SLOT_ID_META, &""))
		if slot_id == &"":
			slot_id = StringName(slot_node.get_meta(WORLD_ID_META, &""))
		if slot_id == &"":
			continue
		var cells := _build_node_footprint(slot_node)
		var occupied := false
		for cell in cells:
			if grid.is_occupied(cell):
				occupied = true
				break
		if occupied:
			continue
		var fp_size: Vector2i = slot_node.get_meta(FOOTPRINT_SIZE_META, Vector2i.ONE)
		var half_size := Vector2(fp_size * tile_size) * 0.5
		var local_pt := slot_node.to_local(world_global_pos)
		if Rect2(-half_size, half_size * 2.0).has_point(local_pt):
			return slot_id
	return &""


func get_placement_slot_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if placement_slots == null:
		return ids
	for child in placement_slots.get_children():
		var slot_node := child as Node2D
		if slot_node == null:
			continue
		var slot_id := StringName(slot_node.get_meta(SLOT_ID_META, &""))
		if slot_id == &"":
			slot_id = StringName(slot_node.get_meta(WORLD_ID_META, &""))
		if slot_id != &"" and not ids.has(slot_id):
			ids.append(slot_id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


func get_placement_slot_view(slot_id: StringName) -> Dictionary:
	if slot_id == &"" or registry == null or grid == null:
		return {}
	var slot_node := registry.get_object(slot_id)
	if slot_node == null or not slot_node.has_meta(SLOT_ID_META):
		return {}
	var raw_allowed: PackedInt32Array = slot_node.get_meta(
		ALLOWED_FIXTURE_KINDS_META,
		PackedInt32Array()
	)
	var allowed_kinds: Array[int] = []
	for k in raw_allowed:
		allowed_kinds.append(int(k))
	var fp_size: Vector2i = slot_node.get_meta(FOOTPRINT_SIZE_META, Vector2i.ONE)
	var cells := _build_node_footprint(slot_node)
	var occupied := false
	for cell in cells:
		if not grid.is_in_bounds(cell) or grid.is_occupied(cell):
			occupied = true
			break
	return {
		"slot_id": slot_id,
		"allowed_fixture_kinds": allowed_kinds,
		"footprint_size": fp_size,
		"cells": cells,
		"occupied": occupied,
		"global_position": slot_node.global_position,
	}


## Returns the SeatAnchor Marker2D child of a registered dining table, if present.
func get_table_seat_anchor(table_id: StringName) -> Marker2D:
	if table_id == &"" or registry == null:
		return null
	var table_node := registry.get_object(table_id)
	if table_node == null or not is_instance_valid(table_node):
		return null
	return table_node.get_node_or_null("SeatAnchor") as Marker2D


## Spawns and registers a physical placed fixture Area2D into KitchenStations or DiningTables.
func spawn_placed_fixture(
	instance_id: StringName,
	fixture_kind: int,
	slot_id: StringName,
	footprint_size: Vector2i
) -> Node2D:
	if instance_id == &"" or slot_id == &"" or registry == null or grid == null:
		return null
	if registry.has_object(instance_id):
		return null
	var slot_node := registry.get_object(slot_id)
	if slot_node == null or not slot_node.has_meta(SLOT_ID_META):
		return null
	var is_table := (fixture_kind == SharedTypes.FixtureKind.DINING_TABLE)
	var container := dining_tables if is_table else kitchen_stations
	if container == null:
		return null

	var area: Area2D = (
		DINING_TABLE_SCENE.instantiate() as Area2D
		if is_table
		else _create_placed_utility_area(fixture_kind, footprint_size)
	)
	if area == null:
		return null

	area.name = String(instance_id)
	area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.position = container.to_local(slot_node.global_position)
	area.set_meta(WORLD_ID_META, instance_id)
	area.set_meta(FOOTPRINT_SIZE_META, footprint_size)
	area.set_meta(SLOT_ID_META, slot_id)

	container.add_child(area)
	var cells := _build_node_footprint(area)
	if cells.is_empty() or not register_object(instance_id, area, cells):
		container.remove_child(area)
		area.free()
		return null
	return area


func _create_placed_utility_area(fixture_kind: int, footprint_size: Vector2i) -> Area2D:
	var area := Area2D.new()
	var region := get_fixture_region_rect(fixture_kind)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = load("res://assets/art/tiles/Warung-Tileset.png") as Texture2D
	if region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = region
		if region.size.y > float(tile_size.y):
			sprite.offset = Vector2(0.0, -0.5 * (region.size.y - float(tile_size.y)))
	area.add_child(sprite)

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(footprint_size * tile_size) - Vector2(4.0, 4.0)
	shape_node.shape = rect_shape
	area.add_child(shape_node)
	return area


func remove_placed_fixture(instance_id: StringName) -> bool:
	if instance_id == &"" or registry == null:
		return false
	var node := registry.get_object(instance_id)
	if node == null:
		return false
	unregister_object(instance_id)
	if is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
	return true


func sync_placement_slot_visuals(
	show_planning_slots: bool,
	occupied_slot_ids: Array[StringName] = []
) -> void:
	if placement_slots == null:
		return
	for child in placement_slots.get_children():
		var slot_node := child as Node2D
		if slot_node == null or not is_instance_valid(slot_node):
			continue
		var slot_id := StringName(slot_node.get_meta(SLOT_ID_META, &""))
		if slot_id == &"":
			slot_id = StringName(slot_node.get_meta(WORLD_ID_META, &""))
		var is_occ := occupied_slot_ids.has(slot_id)
		if not is_occ and grid != null:
			for c in _build_node_footprint(slot_node):
				if grid.is_occupied(c):
					is_occ = true
					break
		var show_ind := show_planning_slots and not is_occ
		var ind := slot_node.get_node_or_null("SlotIndicator") as Node2D
		if ind == null and not show_ind:
			continue
		if ind == null:
			ind = Node2D.new()
			ind.name = "SlotIndicator"
			ind.z_index = 1
			var outline := Polygon2D.new()
			outline.name = "SlotFill"
			outline.polygon = PackedVector2Array([
				Vector2(-13, -13),
				Vector2(13, -13),
				Vector2(13, 13),
				Vector2(-13, 13),
			])
			outline.color = Color(0.32, 0.85, 0.52, 0.28)
			ind.add_child(outline)
			var lbl := Label.new()
			lbl.name = "SlotLabel"
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.position = Vector2(-14, -8)
			lbl.custom_minimum_size = Vector2(28, 16)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 8)
			lbl.modulate = Color(0.75, 1.0, 0.82, 0.95)
			lbl.text = "+Alat" if String(slot_id).contains("utility") else "+Meja"
			ind.add_child(lbl)
			slot_node.add_child(ind)
		ind.visible = show_ind


func get_driver_visual_node(driver_id: StringName) -> Node2D:
	return _driver_visual_nodes.get(driver_id, null)


func get_employee_visual_count() -> int:
	return _employee_visual_nodes.size()


func get_employee_visual_node(employee_id: StringName) -> Node2D:
	return _employee_visual_nodes.get(employee_id, null)


func get_employee_visual_state(employee_id: StringName) -> int:
	var st: Variant = _employee_visual_states.get(employee_id, {})
	if st is Dictionary:
		return int((st as Dictionary).get("state", SharedTypes.EmployeeAnimState.IDLE))
	return SharedTypes.EmployeeAnimState.IDLE


func get_employee_visual_fx_active(employee_id: StringName) -> bool:
	var node := get_employee_visual_node(employee_id)
	if node == null or not is_instance_valid(node):
		return false
	var steam := node.get_node_or_null("SteamFx") as Node2D
	var prop := node.get_node_or_null("WorkProp") as Node2D
	return (steam != null and steam.visible) or (prop != null and prop.visible)


## Synchronizes passive employee visuals and state-driven animations from
## `RunController.get_hired_employees()` and live controller worker states.
## Does not register into WorldGrid or WorldRegistry so player teleport & hitboxes stay intact.
func sync_employee_visuals(
	employees: Array[Dictionary],
	worker_views: Array[Dictionary] = [],
	held_textures: Dictionary = {}
) -> void:
	if employees.is_empty():
		for emp_node: Node2D in _employee_visual_nodes.values():
			if emp_node != null and is_instance_valid(emp_node):
				if emp_node.get_parent() != null:
					emp_node.get_parent().remove_child(emp_node)
				emp_node.free()
		_employee_visual_nodes.clear()
		_employee_visual_states.clear()
		_employee_anim_clock = 0.0
		if _employee_visual_container != null and is_instance_valid(_employee_visual_container):
			if _employee_visual_container.get_parent() != null:
				_employee_visual_container.get_parent().remove_child(_employee_visual_container)
			_employee_visual_container.free()
		_employee_visual_container = null
		return

	if _employee_visual_container == null or not is_instance_valid(_employee_visual_container):
		_employee_visual_container = Node2D.new()
		_employee_visual_container.name = "EmployeeVisuals"
		_employee_visual_container.z_index = 2
		_employee_visual_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_employee_visual_container)

	var seen_ids: Dictionary[StringName, bool] = {}
	for rec: Dictionary in employees:
		var emp_id := StringName(rec.get("employee_id", &""))
		if emp_id != &"":
			seen_ids[emp_id] = true

	for old_id: StringName in _employee_visual_nodes.keys():
		if not seen_ids.has(old_id):
			var old_node := _employee_visual_nodes[old_id]
			_employee_visual_nodes.erase(old_id)
			_employee_visual_states.erase(old_id)
			if old_node != null and is_instance_valid(old_node):
				if old_node.get_parent() != null:
					old_node.get_parent().remove_child(old_node)
				old_node.free()

	var workers_by_id: Dictionary[StringName, Dictionary] = {}
	for wv: Dictionary in worker_views:
		var w_id := StringName(wv.get("employee_id", &""))
		if w_id != &"":
			workers_by_id[w_id] = wv

	var role_counts: Dictionary[StringName, int] = {}
	for rec: Dictionary in employees:
		var emp_id := StringName(rec.get("employee_id", &""))
		var role_id := StringName(rec.get("role_id", &""))
		var display_name := String(rec.get("display_name", ""))
		if emp_id == &"" or role_id == &"":
			continue
		var slot_idx := int(role_counts.get(role_id, 0))
		role_counts[role_id] = slot_idx + 1

		var is_new := not _employee_visual_nodes.has(emp_id)
		var vis_node := _ensure_employee_visual_node(emp_id, role_id, display_name)
		var role_lbl := vis_node.get_node_or_null("RoleLabel") as Label
		if role_lbl != null and not display_name.is_empty():
			role_lbl.text = display_name

		var home_cell := _resolve_employee_home_cell(role_id, slot_idx)
		var home_pos := _resolve_employee_local_pos(role_id, slot_idx)
		if is_new:
			vis_node.position = home_pos

		var wv: Dictionary = workers_by_id.get(emp_id, {})
		var next_state := int(wv.get("state", SharedTypes.EmployeeAnimState.IDLE))
		var target_id := StringName(wv.get("target_id", &""))
		var hold_ing := StringName(wv.get("hold_ingredient_id", &""))
		var hold_rec := StringName(wv.get("hold_recipe_id", &""))
		var hold_tex: Texture2D = null
		if hold_rec != &"" and held_textures.has(hold_rec):
			hold_tex = held_textures[hold_rec] as Texture2D
		elif hold_ing != &"" and held_textures.has(hold_ing):
			hold_tex = held_textures[hold_ing] as Texture2D

		var prev_st: Dictionary = _employee_visual_states.get(emp_id, {})
		var prev_target := StringName(prev_st.get("target_id", &""))
		var prev_state := int(prev_st.get("state", -1))

		var dest_cell := home_cell
		var dest_pos := home_pos
		if next_state != SharedTypes.EmployeeAnimState.IDLE and target_id != &"":
			var from_cell := _local_pos_to_grid_cell(vis_node.position)
			var adj := find_nearest_free_neighbor(target_id, from_cell)
			if adj != INVALID_CELL:
				dest_cell = adj
				dest_pos = _cell_to_local_center(dest_cell)

		var waypoints: Array = []
		var raw_wp: Variant = prev_st.get("waypoints", [])
		if raw_wp is Array:
			waypoints = (raw_wp as Array).duplicate()
		if (
			is_new
			or prev_target != target_id
			or (
				next_state == SharedTypes.EmployeeAnimState.IDLE
				and prev_state != SharedTypes.EmployeeAnimState.IDLE
			)
		):
			if next_state == SharedTypes.EmployeeAnimState.IDLE:
				waypoints = _build_safe_floor_waypoints(vis_node.position, home_cell, home_pos)
			else:
				waypoints = _build_safe_floor_waypoints(vis_node.position, dest_cell, dest_pos)

		_employee_visual_states[emp_id] = {
			"role_id": role_id,
			"state": next_state,
			"target_id": target_id,
			"home_pos": home_pos,
			"dest_pos": dest_pos,
			"waypoints": waypoints,
			"hold_texture": hold_tex,
			"hold_ing": hold_ing,
		}
	_apply_employee_frame_pose_all()


func _ensure_employee_visual_node(
	employee_id: StringName,
	role_id: StringName,
	display_name: String = ""
) -> Node2D:
	if _employee_visual_nodes.has(employee_id):
		var existing := _employee_visual_nodes[employee_id]
		if existing != null and is_instance_valid(existing):
			return existing

	var host := Node2D.new()
	host.name = String(employee_id)
	host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.set_meta(&"employee_id", employee_id)
	host.set_meta(&"role_id", role_id)

	var shadow := Polygon2D.new()
	shadow.name = "FootShadow"
	shadow.polygon = PackedVector2Array([
		Vector2(-5, 9),
		Vector2(5, 9),
		Vector2(6, 11),
		Vector2(-6, 11),
	])
	shadow.color = Color(0.06, 0.04, 0.03, 0.35)
	host.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = employee_texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -4)
	host.add_child(sprite)

	var prop := Node2D.new()
	prop.name = "WorkProp"
	prop.visible = false
	prop.position = Vector2(7, -2)
	prop.z_index = 1
	prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pan := Polygon2D.new()
	pan.name = "PanVisual"
	pan.polygon = PackedVector2Array([
		Vector2(-3, 0),
		Vector2(4, 0),
		Vector2(4, 2),
		Vector2(-3, 2),
	])
	pan.color = Color(0.24, 0.25, 0.30, 1.0)
	pan.visible = false
	prop.add_child(pan)
	var item_spr := Sprite2D.new()
	item_spr.name = "ItemSprite"
	item_spr.position = Vector2(0, -3)
	item_spr.scale = Vector2(0.45, 0.45)
	item_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.add_child(item_spr)
	host.add_child(prop)

	var steam := Node2D.new()
	steam.name = "SteamFx"
	steam.visible = false
	steam.position = Vector2(0, -14)
	steam.z_index = 2
	for i in range(3):
		var puff := Polygon2D.new()
		puff.name = "Puff%d" % i
		puff.polygon = PackedVector2Array([
			Vector2(-1, -1),
			Vector2(2, -1),
			Vector2(2, 1),
			Vector2(-1, 1),
		])
		puff.color = Color(0.98, 0.96, 0.90, 0.85)
		steam.add_child(puff)
	host.add_child(steam)

	var role_lbl := Label.new()
	role_lbl.name = "RoleLabel"
	role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.position = Vector2(-26, -29)
	role_lbl.size = Vector2(52, 12)
	role_lbl.add_theme_font_size_override("font_size", 8)
	role_lbl.add_theme_constant_override("outline_size", 3)
	role_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.03, 0.95))
	match role_id:
		&"cook":
			role_lbl.text = display_name if not display_name.is_empty() else "Koki"
			role_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45, 1.0))
		&"cashier":
			role_lbl.text = display_name if not display_name.is_empty() else "Kasir"
			role_lbl.add_theme_color_override("font_color", Color(0.65, 0.92, 1.0, 1.0))
		_:
			role_lbl.text = display_name if not display_name.is_empty() else "Pelayan"
			role_lbl.add_theme_color_override("font_color", Color(0.72, 1.0, 0.72, 1.0))
	host.add_child(role_lbl)

	_employee_visual_container.add_child(host)
	_employee_visual_nodes[employee_id] = host
	return host


func _step_employee_visual_animations(delta: float) -> void:
	var move_speed := 84.0
	for emp_id: StringName in _employee_visual_nodes:
		var host := _employee_visual_nodes[emp_id]
		if host == null or not is_instance_valid(host):
			continue
		var st: Dictionary = _employee_visual_states.get(emp_id, {})
		var waypoints: Array = st.get("waypoints", [])
		var moving := false
		if not waypoints.is_empty():
			var next_pt := waypoints[0] as Vector2
			var diff := next_pt - host.position
			var dist := diff.length()
			if dist <= move_speed * delta + 0.5:
				host.position = Vector2(roundf(next_pt.x), roundf(next_pt.y))
				waypoints.remove_at(0)
			else:
				var step_pos := host.position + diff.normalized() * move_speed * delta
				host.position = step_pos
				moving = true
			st["waypoints"] = waypoints
		_apply_employee_frame_pose(emp_id, host, st, moving)


func _apply_employee_frame_pose_all() -> void:
	for emp_id: StringName in _employee_visual_nodes:
		var host := _employee_visual_nodes[emp_id]
		if host == null or not is_instance_valid(host):
			continue
		var st: Dictionary = _employee_visual_states.get(emp_id, {})
		_apply_employee_frame_pose(emp_id, host, st, false)


func _apply_employee_frame_pose(
	emp_id: StringName,
	host: Node2D,
	st: Dictionary,
	moving: bool
) -> void:
	var sprite := host.get_node_or_null("Sprite2D") as Sprite2D
	var prop := host.get_node_or_null("WorkProp") as Node2D
	var pan := host.get_node_or_null("WorkProp/PanVisual") as Polygon2D
	var item_spr := host.get_node_or_null("WorkProp/ItemSprite") as Sprite2D
	var steam := host.get_node_or_null("SteamFx") as Node2D
	if sprite == null:
		return

	var role_id := StringName(st.get("role_id", &""))
	var state := int(st.get("state", SharedTypes.EmployeeAnimState.IDLE))
	var phase := _employee_anim_clock + float(abs(emp_id.hash()) % 17) * 0.13
	var hold_tex := st.get("hold_texture", null) as Texture2D

	if moving or state == SharedTypes.EmployeeAnimState.WALK:
		var step_bob := roundf(absf(sin(phase * 14.0)) * -1.0)
		sprite.position = Vector2(0.0, -4.0 + step_bob)
		if prop != null:
			prop.visible = hold_tex != null and state == SharedTypes.EmployeeAnimState.SERVE
			if prop.visible and item_spr != null:
				item_spr.texture = hold_tex
			if pan != null:
				pan.visible = false
		if steam != null:
			steam.visible = false
		return

	match state:
		SharedTypes.EmployeeAnimState.WORK:
			var work_bob := roundf(absf(sin(phase * 9.0)) * -1.0)
			var hand_shift := roundf(sin(phase * 9.0) * 1.0)
			sprite.position = Vector2(0.0, -4.0 + work_bob)
			if prop != null:
				prop.visible = true
				prop.position = Vector2(6.0 + hand_shift, -2.0 + work_bob)
			if pan != null:
				pan.visible = (role_id == &"cook")
			if item_spr != null:
				item_spr.texture = hold_tex
				item_spr.visible = (hold_tex != null)
			if steam != null:
				var is_cooking := (role_id == &"cook")
				steam.visible = is_cooking
				if is_cooking:
					for i in range(3):
						var puff := steam.get_node_or_null("Puff%d" % i) as Polygon2D
						if puff == null:
							continue
						var life := fmod(phase * 1.3 + float(i) * 0.33, 1.0)
						puff.position = Vector2(
							roundf(float((i - 1) * 4) + sin((phase + float(i)) * 4.0) * 1.5),
							roundf(-life * 10.0)
						)
						puff.color.a = clampf((1.0 - life) * 0.9, 0.0, 0.9)
		SharedTypes.EmployeeAnimState.CLEAN:
			var scrub_x := roundf(sin(phase * 11.0) * 1.0)
			sprite.position = Vector2(scrub_x, -4.0)
			if prop != null:
				prop.visible = false
			if steam != null:
				steam.visible = false
		SharedTypes.EmployeeAnimState.SERVE:
			var serve_bob := roundf(absf(sin(phase * 7.0)) * -1.0)
			sprite.position = Vector2(0.0, -4.0 + serve_bob)
			if prop != null:
				prop.visible = (hold_tex != null)
				prop.position = Vector2(6.0, -4.0 + serve_bob)
			if pan != null:
				pan.visible = false
			if item_spr != null:
				item_spr.texture = hold_tex
				item_spr.visible = (hold_tex != null)
			if steam != null:
				steam.visible = false
		_:
			sprite.position = Vector2(0.0, -4.0)
			if prop != null:
				prop.visible = false
			if steam != null:
				steam.visible = false


func _local_pos_to_grid_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor(local_pos.x / float(tile_size.x))), 0, grid_size.x - 1),
		clampi(int(floor(local_pos.y / float(tile_size.y))), 0, grid_size.y - 1)
	)


func _cell_to_local_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(tile_size)


func _build_safe_floor_waypoints(
	from_pos: Vector2,
	dest_cell: Vector2i,
	dest_pos: Vector2
) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var start_cell := _local_pos_to_grid_cell(from_pos)
	var in_kitchen := start_cell.y <= 3
	var dst_kitchen := dest_cell.y <= 3
	var portal := Vector2i(7, 4)
	var portal_pos := _cell_to_local_center(portal)

	if in_kitchen and not dst_kitchen:
		pts.append(_cell_to_local_center(Vector2i(7, start_cell.y)))
		pts.append(portal_pos)
		pts.append(_cell_to_local_center(Vector2i(7, dest_cell.y)))
	elif not in_kitchen and dst_kitchen:
		pts.append(_cell_to_local_center(Vector2i(7, start_cell.y)))
		pts.append(portal_pos)
		pts.append(_cell_to_local_center(Vector2i(7, dest_cell.y)))
	elif start_cell.x != dest_cell.x and start_cell.y != dest_cell.y:
		var mid_y := 1 if dst_kitchen else 6
		pts.append(_cell_to_local_center(Vector2i(start_cell.x, mid_y)))
		pts.append(_cell_to_local_center(Vector2i(dest_cell.x, mid_y)))
	pts.append(dest_pos)
	return pts


func _resolve_employee_home_cell(role_id: StringName, slot_idx: int) -> Vector2i:
	var anchors: Array[Vector2i] = []
	match role_id:
		&"cook":
			anchors = [Vector2i(1, 1), Vector2i(4, 1), Vector2i(6, 1)]
		&"cashier":
			anchors = [Vector2i(5, 3), Vector2i(6, 2), Vector2i(7, 3)]
		_:
			anchors = [Vector2i(1, 6), Vector2i(3, 6), Vector2i(6, 6)]
	return anchors[slot_idx % anchors.size()]


func _resolve_employee_local_pos(role_id: StringName, slot_idx: int) -> Vector2:
	var base_cell := _resolve_employee_home_cell(role_id, slot_idx)
	var stack_tier := int(slot_idx / 3)
	var cell_center := (Vector2(base_cell) + Vector2(0.5, 0.5)) * Vector2(tile_size)
	var offset_x := float((stack_tier % 3) * 8 - (4 if stack_tier > 0 else 0))
	var offset_y := float(int(stack_tier / 3) * 6)
	return cell_center + Vector2(offset_x, offset_y)


## Synchronizes runtime delivery driver visuals under `DriverObjects` from
## `ServiceController.get_driver_views()` without duplicating controller state.
func sync_driver_visuals(
	driver_views: Array[Dictionary],
	recipe_names: Dictionary = {},
	recipe_icons: Dictionary = {}
) -> void:
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
			_remove_driver_visual(old_id, not driver_views.is_empty())

	if driver_views.is_empty() and _customer_visual_nodes.is_empty():
		_clear_departing_visuals()

	var overflow_index := 0
	for view: Dictionary in driver_views:
		var driver_id := StringName(view.get("driver_id", &""))
		if driver_id == &"":
			continue
		var state := int(view.get("state", SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE))
		var spot_id := StringName(view.get("spot_id_or_empty", view.get("spot_id", &"")))
		if state == SharedTypes.DriverState.AT_PICKUP_SPOT and spot_id != &"":
			_sync_in_spot_driver_visual(driver_id, spot_id, view, recipe_names, recipe_icons)
		else:
			var q_idx := int(view.get("queue_index", -1))
			var pos_idx := q_idx if q_idx >= 0 else overflow_index
			_sync_overflow_driver_visual(driver_id, pos_idx, view, recipe_names, recipe_icons)
			overflow_index += 1


func _create_online_preview_visual() -> Node2D:
	var preview := Node2D.new()
	preview.name = "OnlinePreviewVisual"
	preview.z_index = 2
	preview.position = Vector2(0, -14)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var dish := Node2D.new()
	dish.name = "PreviewDish"
	dish.scale = Vector2(0.75, 0.75)
	dish.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.add_child(dish)

	var label := Label.new()
	label.name = "PreviewLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-28, -20)
	label.custom_minimum_size = Vector2(56, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 7)
	preview.add_child(label)
	return preview


func _ensure_driver_visual_node(driver_id: StringName) -> Area2D:
	var existing := _driver_visual_nodes.get(driver_id, null) as Area2D
	if existing != null and is_instance_valid(existing):
		return existing

	var area := Area2D.new()
	area.name = String(driver_id)
	area.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	area.z_index = 1
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

	var bar_bg := ColorRect.new()
	bar_bg.name = "TimerBg"
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.color = Color(0.1, 0.1, 0.12, 0.85)
	bar_bg.position = Vector2(-14, -19)
	bar_bg.size = Vector2(28, 3)
	area.add_child(bar_bg)

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
	label.position = Vector2(-28, -31)
	label.custom_minimum_size = Vector2(56, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 7)
	area.add_child(label)

	driver_objects.add_child(area)
	_driver_visual_nodes[driver_id] = area
	return area


func _update_driver_visual_badge(
	area: Area2D,
	view: Dictionary,
	recipe_names: Dictionary,
	in_spot: bool,
	recipe_icons: Dictionary = {}
) -> void:
	var sprite := area.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.modulate = Color.WHITE if in_spot else Color(0.68, 0.72, 0.78, 0.85)

	var recipe_id := StringName(view.get("recipe_id", &""))
	_sync_order_dish_icon(area, recipe_icons.get(recipe_id, null) as Texture2D, Vector2(0, -40))
	var dish_text: String = String(recipe_names.get(recipe_id, String(recipe_id)))
	var sec_rem: float = maxf(0.0, float(view.get("seconds_remaining", 0.0)))
	var total_secs: float = maxf(0.1, float(view.get("total_seconds", 60.0)))
	var ratio := clampf(sec_rem / total_secs, 0.0, 1.0)

	var label := area.get_node_or_null("StatusLabel") as Label
	if label != null:
		if dish_text.is_empty():
			label.visible = false
			label.text = ""
		else:
			label.visible = true
			var secs_int := maxi(0, ceili(sec_rem))
			label.text = (
				"%s %ds" % [dish_text, secs_int]
				if in_spot
				else "Antre %s %ds" % [dish_text, secs_int]
			)
			label.modulate = Color.WHITE if in_spot else Color(0.85, 0.90, 0.96, 0.95)

	var bar_bg := area.get_node_or_null("TimerBg") as ColorRect
	var bar_fill := area.get_node_or_null("TimerBg/TimerFill") as ColorRect
	var has_timer := view.has("seconds_remaining")
	if bar_bg != null:
		bar_bg.visible = has_timer
	if bar_fill != null:
		bar_fill.size = Vector2(28.0 * ratio, 3.0)
		if not in_spot:
			bar_fill.color = Color(0.58, 0.70, 0.86, 1.0)
		elif ratio <= 0.25:
			bar_fill.color = Color(0.95, 0.28, 0.25, 1.0)
		elif ratio <= 0.55:
			bar_fill.color = Color(0.95, 0.76, 0.25, 1.0)
		else:
			bar_fill.color = Color(0.35, 0.88, 0.42, 1.0)


func _sync_in_spot_driver_visual(
	driver_id: StringName,
	spot_id: StringName,
	view: Dictionary,
	recipe_names: Dictionary,
	recipe_icons: Dictionary = {}
) -> void:
	var spot_node := registry.get_object(spot_id)
	if spot_node == null:
		_remove_driver_visual(driver_id)
		return

	var area := _ensure_driver_visual_node(driver_id)
	_move_npc_host(
		area,
		driver_id,
		spot_node.position,
		_driver_target_positions,
		_driver_tweens,
		_get_driver_child_bases()
	)

	var prev_state := int(_driver_visual_states.get(driver_id, -1))
	var prev_spot := StringName(_driver_visual_spots.get(driver_id, &""))
	var needs_register := (
		prev_state != SharedTypes.DriverState.AT_PICKUP_SPOT
		or prev_spot != spot_id
		or not registry.has_object(driver_id)
	)
	if needs_register:
		if registry.has_object(driver_id):
			unregister_object(driver_id)
		var spot_cell := global_to_cell(spot_node.global_position)
		if not register_object(driver_id, area, [spot_cell]):
			_remove_driver_visual(driver_id)
			return

	_driver_visual_states[driver_id] = SharedTypes.DriverState.AT_PICKUP_SPOT
	_driver_visual_spots[driver_id] = spot_id
	_update_driver_visual_badge(area, view, recipe_names, true, recipe_icons)


func _sync_overflow_driver_visual(
	driver_id: StringName,
	queue_index: int,
	view: Dictionary,
	recipe_names: Dictionary,
	recipe_icons: Dictionary = {}
) -> void:
	var overflow_anchor := registry.get_object(&"driver_overflow")
	var base_pos := overflow_anchor.position if overflow_anchor != null else Vector2(368, 240)
	var target_pos := base_pos + DRIVER_OVERFLOW_STEP * float(queue_index)

	if registry.has_object(driver_id):
		unregister_object(driver_id)

	var area := _ensure_driver_visual_node(driver_id)
	_move_npc_host(
		area,
		driver_id,
		target_pos,
		_driver_target_positions,
		_driver_tweens,
		_get_driver_child_bases()
	)
	_driver_visual_states[driver_id] = SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE
	_driver_visual_spots[driver_id] = &""
	_update_driver_visual_badge(area, view, recipe_names, false, recipe_icons)


func _remove_driver_visual(driver_id: StringName, animate_exit: bool = false) -> void:
	if registry != null and registry.has_object(driver_id):
		unregister_object(driver_id)
	var node: Node2D = _driver_visual_nodes.get(driver_id, null)
	_kill_npc_tween(_driver_tweens, driver_id)
	_driver_target_positions.erase(driver_id)
	_driver_visual_nodes.erase(driver_id)
	_driver_visual_states.erase(driver_id)
	_driver_visual_spots.erase(driver_id)
	if node != null and is_instance_valid(node):
		if animate_exit:
			_spawn_departing_visual(node, Vector2(22, 10))
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


## Synchronizes passive dine-in customer sprites, order/timer badges, and table
## state visuals from read-only controller views without owning gameplay state.
func sync_dine_in_visuals(
	customer_views: Array[Dictionary],
	table_views: Array[Dictionary],
	recipe_names: Dictionary = {},
	recipe_icons: Dictionary = {}
) -> void:
	if registry == null:
		return

	if dine_in_waiting_anchors != null:
		_sync_customer_visuals(customer_views, recipe_names, recipe_icons)
	_sync_dining_table_visuals(table_views)


func get_customer_visual_node(customer_id: StringName) -> Node2D:
	return _customer_visual_nodes.get(customer_id, null)


func is_customer_moving_visually(customer_id: StringName) -> bool:
	var t: Tween = _customer_tweens.get(customer_id, null)
	return t != null and t.is_valid() and t.is_running()


func get_customer_visual_global_position(customer_id: StringName) -> Vector2:
	var node: Node2D = _customer_visual_nodes.get(customer_id, null)
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	var sprite_node := _find_host_visual_sprite(node)
	if sprite_node != null:
		return sprite_node.global_position
	return node.global_position


func is_driver_moving_visually(driver_id: StringName) -> bool:
	var t: Tween = _driver_tweens.get(driver_id, null)
	return t != null and t.is_valid() and t.is_running()


func get_driver_visual_global_position(driver_id: StringName) -> Vector2:
	var node: Node2D = _driver_visual_nodes.get(driver_id, null)
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	var sprite_node := _find_host_visual_sprite(node)
	if sprite_node != null:
		return sprite_node.global_position
	return node.global_position


func get_departing_visual_count() -> int:
	var active := 0
	for vis in _departing_visuals:
		if vis != null and is_instance_valid(vis):
			active += 1
	return active


func _sync_customer_visuals(
	customer_views: Array[Dictionary],
	recipe_names: Dictionary,
	recipe_icons: Dictionary = {}
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
		var target_pos := _resolve_customer_visual_position(view)
		_move_npc_host(
			marker,
			customer_id,
			target_pos,
			_customer_target_positions,
			_customer_tweens,
			_get_customer_child_bases()
		)
		_update_customer_visual_badge(marker, view, recipe_names, recipe_icons)

	var active_left := not seen_ids.is_empty()
	var existing_ids := _customer_visual_nodes.keys()
	for old_id: StringName in existing_ids:
		if not seen_ids.has(old_id):
			_remove_customer_visual(old_id, active_left)

	if not active_left and _driver_visual_nodes.is_empty():
		_clear_departing_visuals()


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
		return Vector2(304, 80) + CUSTOMER_OVERFLOW_STEP * float(queue_idx)

	var table_id := StringName(view.get("assigned_table_id", &""))
	var seat_anchor := get_table_seat_anchor(table_id)
	if seat_anchor != null:
		return dine_in_waiting_anchors.to_local(seat_anchor.global_position)
	var table_node := registry.get_object(table_id)
	if table_node != null:
		return dine_in_waiting_anchors.to_local(table_node.global_position) + Vector2(0, 16)
	return Vector2(80, 256)


func _update_customer_visual_badge(
	marker: Node2D,
	view: Dictionary,
	recipe_names: Dictionary,
	recipe_icons: Dictionary = {}
) -> void:
	var state: int = int(view.get("state", -1))
	var label := marker.get_node_or_null("StatusLabel") as Label
	var bar_fill := marker.get_node_or_null("TimerBg/TimerFill") as ColorRect
	var ratio := 1.0

	if state == SharedTypes.CustomerState.EATING:
		_sync_order_dish_icon(marker, null, Vector2(0, -43))
		var eat_rem: float = float(view.get("eat_seconds_remaining", 0.0))
		var eat_total: float = maxf(0.1, float(view.get("eat_total_seconds", 20.0)))
		ratio = clampf(eat_rem / eat_total, 0.0, 1.0)
		if label != null:
			label.text = "Makan %ds" % ceili(eat_rem)
		if bar_fill != null:
			bar_fill.color = Color(0.4, 0.78, 0.96, 1.0)
	else:
		var recipe_id := StringName(view.get("recipe_id", &""))
		_sync_order_dish_icon(marker, recipe_icons.get(recipe_id, null) as Texture2D, Vector2(0, -43))
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


func _remove_customer_visual(customer_id: StringName, animate_exit: bool = false) -> void:
	var node: Node2D = _customer_visual_nodes.get(customer_id, null)
	_kill_npc_tween(_customer_tweens, customer_id)
	_customer_target_positions.erase(customer_id)
	_customer_visual_nodes.erase(customer_id)
	if node != null and is_instance_valid(node):
		if animate_exit:
			_spawn_departing_visual(node, Vector2(-20, 12))
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _get_customer_child_bases() -> Dictionary:
	return {
		"Sprite2D": Vector2.ZERO,
		"FallbackBody": Vector2.ZERO,
		"TimerBg": Vector2(-14, -22),
		"StatusLabel": Vector2(-24, -34),
		"OrderDishIcon": Vector2(0, -43),
	}


func _get_driver_child_bases() -> Dictionary:
	return {
		"Sprite2D": Vector2.ZERO,
		"TimerBg": Vector2(-14, -19),
		"StatusLabel": Vector2(-28, -31),
		"OrderDishIcon": Vector2(0, -40),
	}


func _sync_order_dish_icon(host: Node2D, tex: Texture2D, base_pos: Vector2) -> void:
	if host == null:
		return
	var icon := host.get_node_or_null("OrderDishIcon") as Sprite2D
	if tex == null:
		if icon != null:
			icon.visible = false
		return
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "OrderDishIcon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2(0.5625, 0.5625)
		icon.z_index = 2
		icon.position = base_pos
		host.add_child(icon)
	icon.texture = tex
	icon.visible = true


func _find_host_visual_sprite(host: Node2D) -> Node2D:
	var spr := host.get_node_or_null("Sprite2D") as Node2D
	if spr != null:
		return spr
	return host.get_node_or_null("FallbackBody") as Node2D


func _move_npc_host(
	host: Node2D,
	entity_id: StringName,
	target_pos: Vector2,
	target_map: Dictionary,
	tween_map: Dictionary,
	child_bases: Dictionary
) -> void:
	if not target_map.has(entity_id):
		host.position = target_pos
		target_map[entity_id] = target_pos
		return

	var prev_target: Vector2 = target_map[entity_id]
	if prev_target.is_equal_approx(target_pos):
		return

	var sprite_node := _find_host_visual_sprite(host)
	var cur_child_offset := sprite_node.position if sprite_node != null else Vector2.ZERO
	var visual_offset := (prev_target + cur_child_offset) - target_pos

	_kill_npc_tween(tween_map, entity_id)
	host.position = target_pos
	target_map[entity_id] = target_pos

	if not host.is_inside_tree() or visual_offset.length() < 1.0:
		for child_name: String in child_bases:
			var child := host.get_node_or_null(child_name)
			if child != null:
				child.set("position", child_bases[child_name])
		return

	var duration := clampf(0.10 + visual_offset.length() / 320.0, 0.14, 0.30)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween_map[entity_id] = tween

	for child_name: String in child_bases:
		var child := host.get_node_or_null(child_name)
		if child == null:
			continue
		var base_pos: Vector2 = child_bases[child_name]
		child.set("position", base_pos + visual_offset)
		tween.tween_property(child, "position", base_pos, duration)


func _spawn_departing_visual(source_host: Node2D, exit_delta: Vector2) -> void:
	if decorations == null or not is_inside_tree():
		return
	var source_sprite := _find_host_visual_sprite(source_host)
	if source_sprite == null:
		return

	var ghost := Node2D.new()
	ghost.name = "DepartingVisual_%d" % _departing_visuals.size()
	ghost.z_index = source_host.z_index
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.position = decorations.to_local(source_sprite.global_position)

	if source_sprite is Sprite2D:
		var spr_copy := Sprite2D.new()
		spr_copy.texture = (source_sprite as Sprite2D).texture
		spr_copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.add_child(spr_copy)
	elif source_sprite is Polygon2D:
		var poly_copy := Polygon2D.new()
		poly_copy.polygon = (source_sprite as Polygon2D).polygon
		poly_copy.color = (source_sprite as Polygon2D).color
		ghost.add_child(poly_copy)

	decorations.add_child(ghost)
	_departing_visuals.append(ghost)

	var tween := ghost.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(ghost, "position", ghost.position + exit_delta, 0.22)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	_departing_tweens.append(tween)
	tween.finished.connect(
		func() -> void:
			_departing_tweens.erase(tween)
			_departing_visuals.erase(ghost)
			if is_instance_valid(ghost):
				if ghost.get_parent() != null:
					ghost.get_parent().remove_child(ghost)
				ghost.free()
	)


func _kill_npc_tween(tween_map: Dictionary, entity_id: StringName) -> void:
	var t: Tween = tween_map.get(entity_id, null)
	tween_map.erase(entity_id)
	if t != null and t.is_valid():
		t.kill()


func _clear_departing_visuals() -> void:
	for t in _departing_tweens:
		if t != null and t.is_valid():
			t.kill()
	_departing_tweens.clear()
	for ghost in _departing_visuals:
		if ghost != null and is_instance_valid(ghost):
			if ghost.get_parent() != null:
				ghost.get_parent().remove_child(ghost)
			ghost.free()
	_departing_visuals.clear()


func _clear_all_visual_tweens() -> void:
	for cid: StringName in _customer_tweens.keys():
		_kill_npc_tween(_customer_tweens, cid)
	for did: StringName in _driver_tweens.keys():
		_kill_npc_tween(_driver_tweens, did)
	_clear_departing_visuals()


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
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var dirty_plate := Sprite2D.new()
	dirty_plate.name = "DirtyPlate"
	dirty_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dirty_plate.texture = DIRTY_PLATE_TEXTURE
	dirty_plate.scale = Vector2(0.75, 0.75)
	container.add_child(dirty_plate)
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

	_fill_flat_zone(kitchen_rect, TILE_KITCHEN_FLOOR)
	_fill_flat_zone(dining_rect, TILE_DINING_FLOOR)
	_fill_flat_zone(Rect2i(8, 0, 1, 4), TILE_KITCHEN_FLOOR)
	_fill_flat_zone(Rect2i(8, 4, 1, 5), TILE_DINING_FLOOR)
	if (
		floor_layer.tile_set.has_source(SIDEWALK_SOURCE_ID)
		and floor_layer.tile_set.has_source(ROAD_SOURCE_ID)
	):
		_fill_road_and_sidewalk()
	else:
		var exterior_road_rect := waiting_lane_rect.merge(online_rect)
		_fill_bordered_lane(exterior_road_rect)


func _fill_road_and_sidewalk() -> void:
	for y in range(waiting_lane_rect.position.y, waiting_lane_rect.end.y):
		for x in range(waiting_lane_rect.position.x, waiting_lane_rect.end.x):
			floor_layer.set_cell(
				Vector2i(x, y),
				SIDEWALK_SOURCE_ID,
				TILE_SIDEWALK,
				SIDEWALK_ALT_DEFAULT
			)
	for y in range(online_rect.position.y, online_rect.end.y):
		var road_coords := TILE_ROAD_TOP if (y % 2 == 0) else TILE_ROAD_BOTTOM
		floor_layer.set_cell(
			Vector2i(online_rect.position.x, y),
			ROAD_SOURCE_ID,
			road_coords
		)
		for x in range(online_rect.position.x + 1, online_rect.end.x):
			floor_layer.set_cell(
				Vector2i(x, y),
				SIDEWALK_SOURCE_ID,
				TILE_SIDEWALK,
				SIDEWALK_ALT_FLIPPED
			)


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
			if is_left and is_right:
				if is_top:
					coords = TILE_SINGLE_LANE_TOP
				elif is_bot:
					coords = TILE_SINGLE_LANE_BOT
				else:
					coords = TILE_SINGLE_LANE_MID
			elif is_top and is_left:
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
