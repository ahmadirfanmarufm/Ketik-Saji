extends SceneTree
## Headless tests for Milestone 0 World Hierarchy Migration: canonical containers,
## WorkTable split targets, OnlineStation, PlacementSlots metadata, and stateless
## spatial neighbor/Manhattan queries.

const CANONICAL_CONTAINERS: Array[String] = [
	"FloorTiles",
	"DineInWaitingAnchors",
	"Player",
	"KitchenStations",
	"KitchenWorkTables",
	"DiningTables",
	"OnlineStation",
	"DriverPickupSpots",
	"DriverOverflowAnchors",
	"DriverObjects",
	"PlacementSlots",
	"Decorations",
]

const INTERACTABLE_IDS: Array[StringName] = [
	&"storage_box",
	&"stove",
	&"washer",
	&"plate_rack",
	&"rice_cooker",
	&"trash",
	&"work_table",
	&"work_table_stage",
	&"work_table_chop",
	&"dining_table_01",
	&"dining_table_02",
	&"online_station",
]

const PICKUP_SPOT_IDS: Array[StringName] = [
	&"pickup_spot_01",
	&"pickup_spot_02",
	&"pickup_spot_03",
]

const WAITING_ANCHOR_IDS: Array[StringName] = [
	&"dine_in_wait_01",
	&"dine_in_wait_02",
	&"dine_in_wait_03",
	&"dine_in_wait_04",
]

const SLOT_IDS: Array[StringName] = [
	&"slot_utility_01",
	&"slot_utility_02",
	&"slot_table_01",
	&"slot_table_02",
]

var _fails: int = 0


func _check(label: String, condition: bool) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		_fails += 1


func _init() -> void:
	await _run_all()
	print("SUMMARY fails=%d" % _fails)
	quit(_fails)


func _run_all() -> void:
	var packed := load("res://scenes/main/game_root.tscn") as PackedScene
	_check("load game_root.tscn", packed != null)
	if packed == null:
		return

	var game_root := packed.instantiate()
	root.add_child(game_root)
	await process_frame

	var world := game_root.get_node_or_null("World") as WorldMap
	_check("GameRoot/World is WorldMap", world != null)
	if world == null:
		game_root.free()
		return

	_test_canonical_containers(world)
	_test_starter_fixtures_and_unique_ids(world)
	_test_work_table_split_targets(world)
	_test_placement_slots_and_markers(world)
	_test_visual_only_nodes(world)
	_test_art_integration_and_driver_visuals(world)
	_test_interactable_neighbors_and_queries(world)
	await _test_multi_tile_and_negative_queries(world)

	game_root.free()
	await process_frame


func _test_canonical_containers(world: WorldMap) -> void:
	var child_names: Array[String] = []
	for child in world.get_children():
		child_names.append(child.name)

	_check("exact 12 canonical World children", child_names == CANONICAL_CONTAINERS)
	_check("obsolete WaitingLane removed", world.get_node_or_null("WaitingLane") == null)
	_check("obsolete OnlineArea removed", world.get_node_or_null("OnlineArea") == null)
	_check(
		"WorkTable moved out of KitchenStations",
		world.get_node_or_null("KitchenStations/WorkTable") == null
		and world.get_node_or_null("KitchenWorkTables/WorkTable") != null
	)
	_check("OnlineStation is Area2D", world.online_station is Area2D)


func _test_starter_fixtures_and_unique_ids(world: WorldMap) -> void:
	_check("KitchenStations count == 6", world.kitchen_stations.get_child_count() == 6)
	_check("KitchenWorkTables count == 1", world.kitchen_work_tables.get_child_count() == 1)
	_check("DiningTables count == 2", world.dining_tables.get_child_count() == 2)
	_check("DriverPickupSpots count == 3", world.driver_pickup_spots.get_child_count() == 3)
	_check(
		"DriverOverflowAnchors count == 1",
		world.driver_overflow_anchors.get_child_count() == 1
	)
	_check("DriverObjects starts empty", world.driver_objects.get_child_count() == 0)

	var ids := world.registry.get_ids()
	_check("24 unique scene IDs registered", ids.size() == 24)

	for id in INTERACTABLE_IDS + PICKUP_SPOT_IDS + WAITING_ANCHOR_IDS + SLOT_IDS:
		_check("registered ID " + String(id), world.registry.has_object(id))
	_check("registered driver_overflow", world.registry.has_object(&"driver_overflow"))


func _test_work_table_split_targets(world: WorldMap) -> void:
	var table_node := world.registry.get_object(&"work_table")
	var stage_node := world.registry.get_object(&"work_table_stage") as Area2D
	var chop_node := world.registry.get_object(&"work_table_chop") as Area2D

	_check("work_table and split targets exist",
		table_node != null and stage_node != null and chop_node != null
	)
	if table_node == null or stage_node == null or chop_node == null:
		return

	_check(
		"split targets are children of WorkTable",
		stage_node.get_parent() == table_node and chop_node.get_parent() == table_node
	)
	_check(
		"split targets link parent_world_id",
		stage_node.get_meta(WorldMap.PARENT_WORLD_ID_META, &"") == &"work_table"
		and chop_node.get_meta(WorldMap.PARENT_WORLD_ID_META, &"") == &"work_table"
	)

	var expected_cell := Vector2i(6, 2)
	_check(
		"WorkTable owns grid footprint once",
		world.grid.get_occupant(expected_cell) == &"work_table"
		and world.grid.get_footprint(&"work_table") == [expected_cell]
		and world.grid.get_footprint(&"work_table_stage").is_empty()
		and world.grid.get_footprint(&"work_table_chop").is_empty()
	)
	_check(
		"get_target_footprint resolves split targets to parent cell",
		world.get_target_footprint(&"work_table_stage") == [expected_cell]
		and world.get_target_footprint(&"work_table_chop") == [expected_cell]
	)

	var stage_shape := stage_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var chop_shape := chop_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check("split targets have CollisionShape2D", stage_shape != null and chop_shape != null)
	if stage_shape != null and chop_shape != null:
		var s_rect := (stage_shape.shape as RectangleShape2D).get_rect()
		s_rect.position += stage_node.position
		var c_rect := (chop_shape.shape as RectangleShape2D).get_rect()
		c_rect.position += chop_node.position
		_check("split target hitboxes do not overlap", not s_rect.intersects(c_rect))


func _test_placement_slots_and_markers(world: WorldMap) -> void:
	for slot_id in SLOT_IDS:
		var slot := world.registry.get_object(slot_id)
		_check("slot node exists " + String(slot_id), slot != null)
		if slot == null:
			continue

		var meta_slot_id := StringName(slot.get_meta(WorldMap.SLOT_ID_META, &""))
		var allowed: PackedInt32Array = slot.get_meta(
			WorldMap.ALLOWED_FIXTURE_KINDS_META,
			PackedInt32Array()
		)
		var fp_size: Vector2i = slot.get_meta(WorldMap.FOOTPRINT_SIZE_META, Vector2i.ZERO)
		var cell := world.global_to_cell(slot.global_position)

		_check("slot_id metadata matches " + String(slot_id), meta_slot_id == slot_id)
		_check("slot allowed_fixture_kinds non-empty " + String(slot_id), not allowed.is_empty())
		_check("slot footprint_size positive " + String(slot_id), fp_size.x > 0 and fp_size.y > 0)
		_check(
			"empty slot does not occupy walkable floor " + String(slot_id),
			world.grid.is_free(cell) and world.get_target_footprint(slot_id).is_empty()
		)
		_check("slot has no Area2D/collision " + String(slot_id), not (slot is Area2D))

	for spot_id in PICKUP_SPOT_IDS:
		var spot := world.registry.get_object(spot_id)
		var spot_cell := world.global_to_cell(spot.global_position)
		var has_free_neighbor := false
		for n in world.grid.get_cardinal_neighbors(spot_cell):
			if world.grid.is_free(n):
				has_free_neighbor = true
		_check("pickup spot has free cardinal neighbor " + String(spot_id), has_free_neighbor)
		_check("pickup spot is Marker2D not fixture " + String(spot_id),
			spot is Marker2D and not world.grid.is_occupied(spot_cell))


func _test_visual_only_nodes(world: WorldMap) -> void:
	_check(
		"Player not registered in WorldRegistry",
		world.registry.find_id(world.player) == &""
		and not world.registry.has_object(&"player")
	)
	_check(
		"Decorations not registered in WorldRegistry",
		world.registry.find_id(world.decorations) == &""
		and world.decorations.get_child_count() == 0
	)
	_check("Player cell (6, 4) remains free", world.grid.is_free(Vector2i(6, 4)))


func _test_art_integration_and_driver_visuals(world: WorldMap) -> void:
	_check(
		"FloorTiles has TileSet and 117 populated cells with nearest filter",
		world.floor_layer.tile_set != null
		and world.floor_layer.tile_set.tile_size == Vector2i(32, 32)
		and world.floor_layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and world.floor_layer.get_used_cells().size() == 117
		and world.floor_layer.get_cell_atlas_coords(Vector2i(5, 2)) == WorldMap.TILE_KITCHEN_FLOOR
		and world.floor_layer.get_cell_atlas_coords(Vector2i(5, 6)) == WorldMap.TILE_DINING_FLOOR
	)

	var player_sprite := world.player.get_node_or_null("Visual/Sprite") as Sprite2D
	_check(
		"Player sprite uses player.png (16x32) with nearest filter and z_index 1",
		player_sprite != null
		and player_sprite.texture != null
		and player_sprite.texture.resource_path == "res://assets/art/characters/player.png"
		and player_sprite.texture.get_size() == Vector2(16, 32)
		and player_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and world.player.z_index == 1
	)

	var expected_regions: Dictionary[StringName, Rect2] = {
		&"storage_box": WorldMap.REGION_STORAGE_BOX,
		&"stove": WorldMap.REGION_STOVE,
		&"washer": WorldMap.REGION_WASHER,
		&"plate_rack": WorldMap.REGION_PLATE_RACK,
		&"rice_cooker": WorldMap.REGION_RICE_COOKER,
		&"trash": WorldMap.REGION_TRASH,
		&"work_table": WorldMap.REGION_WORK_TABLE,
		&"dining_table_01": WorldMap.REGION_DINING_TABLE,
		&"dining_table_02": WorldMap.REGION_DINING_TABLE,
		&"online_station": WorldMap.REGION_ONLINE_STATION,
	}
	for fixture_id: StringName in expected_regions:
		var node := world.registry.get_object(fixture_id)
		var spr := node.get_node_or_null("Sprite2D") as Sprite2D if node != null else null
		_check(
			"fixture sprite integrated " + String(fixture_id),
			spr != null
			and spr.texture != null
			and spr.texture.resource_path == "res://assets/art/tiles/Warung-Tileset.png"
			and spr.region_enabled
			and spr.region_rect == expected_regions[fixture_id]
			and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		)

	_check(
		"WorldMap character textures bound (gojek, pegawai, 7 customer variants)",
		world.driver_texture != null
		and world.driver_texture.resource_path == "res://assets/art/characters/npc gojek.png"
		and world.employee_texture != null
		and world.employee_texture.resource_path == "res://assets/art/characters/pegawai.png"
		and world.customer_textures.size() == 7
		and world.get_customer_texture_by_index(0) != null
		and world.get_customer_texture_for_id(&"cust_1_01") != null
	)

	# Verify GoFood driver visual sync for pickup spot and overflow:
	world.sync_driver_visuals([
		{
			"driver_id": &"drv_test_01",
			"order_id": &"ord_test_01",
			"state": SharedTypes.DriverState.AT_PICKUP_SPOT,
			"spot_id_or_empty": &"pickup_spot_01",
		},
		{
			"driver_id": &"drv_test_02",
			"order_id": &"ord_test_02",
			"state": SharedTypes.DriverState.OUTSIDE_DRIVER_QUEUE,
			"spot_id_or_empty": &"",
		},
	])
	var spot_drv := world.registry.get_object(&"drv_test_01")
	_check(
		"in-spot driver registered as Area2D at pickup_spot_01 with free neighbor (10, 2)",
		spot_drv is Area2D
		and spot_drv.position == Vector2(368, 80)
		and world.get_free_cardinal_neighbors(&"drv_test_01") == [Vector2i(10, 2)]
		and not world.registry.has_object(&"drv_test_02")
		and world.driver_objects.get_child_count() == 2
	)
	world.sync_driver_visuals([])
	_check(
		"clearing driver visuals cleans DriverObjects and WorldRegistry",
		world.driver_objects.get_child_count() == 0
		and not world.registry.has_object(&"drv_test_01")
		and not world.grid.is_occupied(Vector2i(11, 2))
	)


func _test_interactable_neighbors_and_queries(world: WorldMap) -> void:
	for target_id in INTERACTABLE_IDS:
		var free_neighbors := world.get_free_cardinal_neighbors(target_id)
		var nearest := world.find_nearest_free_neighbor(target_id, Vector2i(6, 4))
		_check(
			"interactable has free cardinal neighbor " + String(target_id),
			not free_neighbors.is_empty() and free_neighbors.has(nearest)
		)

	# OnlineStation at (11, 1) is in non-walkable online_rect; only (10, 1) is walkable & free.
	_check(
		"online_station neighbor is (10, 1)",
		world.get_free_cardinal_neighbors(&"online_station") == [Vector2i(10, 1)]
		and world.find_nearest_free_neighbor(&"online_station", Vector2i(6, 4))
			== Vector2i(10, 1)
	)

	# DiningTable01 at (4, 6) has 4 free neighbors: UP(4,5), RIGHT(5,6), DOWN(4,7), LEFT(3,6).
	var dt1_neighbors := world.get_free_cardinal_neighbors(&"dining_table_01")
	_check(
		"dining_table_01 cardinal neighbor order UP/RIGHT/DOWN/LEFT",
		dt1_neighbors == [
			Vector2i(4, 5),
			Vector2i(5, 6),
			Vector2i(4, 7),
			Vector2i(3, 6),
		]
	)
	# Tie-break checks around DiningTable01 (4, 6):
	# From (5, 5), UP(4, 5) and RIGHT(5, 6) both have Manhattan distance 1 -> UP(4, 5) wins.
	_check(
		"tie-break UP beats RIGHT from (5, 5)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(5, 5))
			== Vector2i(4, 5)
	)
	# From (5, 7), RIGHT(5, 6) and DOWN(4, 7) both have distance 1 -> RIGHT(5, 6) wins.
	_check(
		"tie-break RIGHT beats DOWN from (5, 7)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(5, 7))
			== Vector2i(5, 6)
	)
	# From (3, 7), DOWN(4, 7) and LEFT(3, 6) both have distance 1 -> DOWN(4, 7) wins.
	_check(
		"tie-break DOWN beats LEFT from (3, 7)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(3, 7))
			== Vector2i(4, 7)
	)
	# From (2, 6), LEFT(3, 6) has unique shortest distance 1 -> LEFT(3, 6) wins.
	_check(
		"shortest Manhattan distance wins from (2, 6)",
		world.find_nearest_free_neighbor(&"dining_table_01", Vector2i(2, 6))
			== Vector2i(3, 6)
	)


func _test_multi_tile_and_negative_queries(world: WorldMap) -> void:
	# Unknown / empty target IDs and passive markers fail safely.
	_check("empty target_id footprint empty", world.get_target_footprint(&"").is_empty())
	_check("unknown target_id footprint empty", world.get_target_footprint(&"no_such").is_empty())
	_check(
		"unknown target_id nearest returns INVALID_CELL",
		world.find_nearest_free_neighbor(&"no_such", Vector2i(6, 4)) == WorldMap.INVALID_CELL
	)
	_check(
		"out-of-bounds from_cell returns INVALID_CELL",
		world.find_nearest_free_neighbor(&"stove", Vector2i(-1, -1)) == WorldMap.INVALID_CELL
		and world.find_nearest_free_neighbor(&"stove", Vector2i(99, 99)) == WorldMap.INVALID_CELL
	)
	_check(
		"waiting anchor has empty fixture footprint",
		world.get_target_footprint(&"dine_in_wait_01").is_empty()
	)

	# Child target with broken parent_world_id fails safely.
	var bad_child := Node2D.new()
	bad_child.set_meta(WorldMap.PARENT_WORLD_ID_META, &"missing_parent")
	world.add_child(bad_child)
	_check("register bad_child", world.register_object(&"bad_child", bad_child, []))
	_check(
		"broken parent_world_id returns empty footprint and INVALID_CELL",
		world.get_target_footprint(&"bad_child").is_empty()
		and world.find_nearest_free_neighbor(&"bad_child", Vector2i(6, 4))
			== WorldMap.INVALID_CELL
	)
	bad_child.queue_free()
	await process_frame
	await process_frame
	_check(
		"bad_child auto-unregistered on queue_free",
		not world.registry.has_object(&"bad_child")
	)

	# Multi-tile 2x1 fixture registration and neighbor query.
	var wide_fixture := Node2D.new()
	world.add_child(wide_fixture)
	var cells: Array[Vector2i] = [Vector2i(5, 4), Vector2i(6, 4)]
	_check("register 2x1 wide_fixture", world.register_object(&"wide_fix", wide_fixture, cells))
	_check("wide_fixture footprint matches", world.get_target_footprint(&"wide_fix") == cells)
	_check(
		"wide_fixture nearest from (6, 3) is (6, 3)",
		world.find_nearest_free_neighbor(&"wide_fix", Vector2i(6, 3)) == Vector2i(6, 3)
	)
	wide_fixture.queue_free()
	await process_frame
	await process_frame
	_check(
		"wide_fixture cells released after queue_free",
		world.grid.is_free(Vector2i(5, 4)) and world.grid.is_free(Vector2i(6, 4))
	)
